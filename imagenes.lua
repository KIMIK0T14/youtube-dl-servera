-- imagenes.lua
-- Módulo: Convertir imágenes a bloques (procesamiento LOCAL, sin servidor externo)
-- Compatible con Luau (Roblox) - usa bit32 en lugar de operadores bitwise de Lua 5.3

local ImagenesModule = {}

function ImagenesModule.init(ENV)
    local mk          = ENV.mk
    local corner      = ENV.corner
    local stroke      = ENV.stroke
    local pad         = ENV.pad
    local lbl         = ENV.lbl
    local box         = ENV.box
    local btn         = ENV.btn
    local T           = ENV.T
    local SG          = ENV.SG
    local Body        = ENV.Body
    local RunService  = ENV.RunService
    local Camera      = ENV.Camera
    local Mouse       = ENV.Mouse
    local LP          = ENV.LP
    local equipTool   = ENV.equipTool
    local userFolder  = ENV.userFolder
    local isSharing   = ENV.isSharing
    local getActiveData  = ENV.getActiveData
    local getActiveTool  = ENV.getActiveTool
    local paintBatch     = ENV.paintBatch
    local closestZone    = ENV.closestZone
    local myRefPos       = ENV.myRefPos
    local FSys        = ENV.FSys
    local prevF       = ENV.prevF
    local envF        = ENV.envF
    local ICON_MOVE   = ENV.ICON_MOVE
    local ICON_ROT    = ENV.ICON_ROT
    local gbRunRef    = ENV.gbRunning

    -- bit32 aliases para claridad
    local bor    = bit32.bor
    local band   = bit32.band
    local bxor   = bit32.bxor
    local lshift = bit32.lshift
    local rshift = bit32.rshift

    local WHITE  = Color3.fromRGB(255,255,255)
    local BLACK  = Color3.fromRGB(0,0,0)
    local DEF_IMG = "rbxassetid://12328114032"

    local IMG_DIR = "Build a Boat For Treasure/images"
    FSys.mkf(IMG_DIR)

    local updateHandles, mPv, hPv, setStat, selectImage, refreshGrid

    local selImage      = nil
    local isProcessing  = false
    local selBlockName  = "PlasticBlock"
    local pOn           = true
    local pA            = 0.55
    local cP            = nil
    local baseCPos      = nil
    local tM            = "move"
    local sR            = CFrame.identity
    local hR            = false
    local bS            = {running=false, cancel=false}
    local needsRecenter = false
    local sBMat         = Enum.Material.Plastic
    local sBCol         = Color3.fromRGB(163,162,165)
    local lk            = false

    -- ================================================================
    -- INFLATE / DEFLATE en Lua puro compatible con Luau (bit32)
    -- ================================================================

    -- buildHuffman: recibe tabla de longitudes de código (1-indexed, sym = i-1)
    -- Devuelve tree (tabla code->sym) y maxLen
    local function buildHuffman(lengths)
        local maxLen = 0
        for i = 1, #lengths do
            if lengths[i] > maxLen then maxLen = lengths[i] end
        end
        if maxLen == 0 then return {}, 0 end

        -- Contar cuántos símbolos tienen cada longitud
        local bl_count = {}
        for i = 0, maxLen do bl_count[i] = 0 end
        for i = 1, #lengths do
            local l = lengths[i]
            if l > 0 then bl_count[l] = bl_count[l] + 1 end
        end

        -- Calcular primer código para cada longitud
        local next_code = {}
        local code = 0
        bl_count[0] = 0
        for bits = 1, maxLen do
            code = (code + bl_count[bits-1]) * 2
            next_code[bits] = code
        end

        -- Asignar códigos e invertir bits (DEFLATE usa LSB-first)
        local tree = {}
        for i = 1, #lengths do
            local l = lengths[i]
            if l > 0 then
                local sym = i - 1
                local c = next_code[l]
                next_code[l] = c + 1
                -- Invertir los l bits de c
                local rev = 0
                local tmp = c
                for _ = 1, l do
                    rev = rev * 2 + (tmp % 2)
                    tmp = math.floor(tmp / 2)
                end
                -- Clave única: código invertido * 32 + longitud
                tree[rev * 32 + l] = sym
            end
        end
        return tree, maxLen
    end

    -- inflate: descomprime datos DEFLATE con cabecera zlib (2 bytes al inicio)
    local function inflate(data)
        local dataLen = #data
        local pos = 3   -- saltar cabecera zlib (CMF + FLG)

        -- Buffer de bits
        local buf  = 0   -- bits acumulados
        local nbits = 0  -- cuántos bits válidos hay en buf

        local function readByte()
            if pos > dataLen then return 0 end
            local b = data:byte(pos)
            pos = pos + 1
            return b
        end

        -- Leer n bits (LSB first, como DEFLATE)
        local function readBits(n)
            if n == 0 then return 0 end
            while nbits < n do
                buf = buf + readByte() * lshift(1, nbits)
                nbits = nbits + 8
            end
            local mask = lshift(1, n) - 1
            local v = band(buf, mask)
            buf = math.floor(buf / lshift(1, n))
            nbits = nbits - n
            return v
        end

        -- Decodificar un símbolo huffman del árbol
        local function decodeHuff(tree, maxLen)
            local code = 0
            local len  = 0
            for _ = 1, maxLen do
                len = len + 1
                -- Leer 1 bit y agregar al MSB del código
                local bit = readBits(1)
                code = code * 2 + bit
                local sym = tree[code * 32 + len]
                if sym ~= nil then return sym end
            end
            error("huffman: código inválido en offset " .. tostring(pos))
        end

        -- Tablas DEFLATE estándar
        local LENS_BASE  = {3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,
                            35,43,51,59,67,83,99,115,131,163,195,227,258}
        local LENS_EXTRA = {0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,
                            3,3,3,3,4,4,4,4,5,5,5,5,0}
        local DIST_BASE  = {1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,
                            257,385,513,769,1025,1537,2049,3073,4097,6145,
                            8193,12289,16385,24577}
        local DIST_EXTRA = {0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,
                            7,7,8,8,9,9,10,10,11,11,12,12,13,13}

        -- Árboles huffman fijos (btype=1)
        local FIXED_LL, FIXED_DIST
        do
            local ll = {}
            for i = 1,  144 do ll[i] = 8 end
            for i = 145,256 do ll[i] = 9 end
            for i = 257,280 do ll[i] = 7 end
            for i = 281,288 do ll[i] = 8 end
            FIXED_LL = buildHuffman(ll)
            local dl = {}
            for i = 1, 32 do dl[i] = 5 end
            FIXED_DIST = buildHuffman(dl)
        end

        local out    = {}
        local outLen = 0
        local BFINAL = 0

        repeat
            BFINAL = readBits(1)
            local BTYPE = readBits(2)

            if BTYPE == 0 then
                -- Bloque sin compresión: alinear al byte
                buf   = 0
                nbits = 0
                local len  = readByte() + readByte() * 256
                local _    = readByte() + readByte() * 256  -- nlen (ignorado)
                for _ = 1, len do
                    outLen = outLen + 1
                    out[outLen] = readByte()
                end

            elseif BTYPE == 1 then
                -- Huffman fijo
                while true do
                    local sym = decodeHuff(FIXED_LL, 9)
                    if sym < 256 then
                        outLen = outLen + 1
                        out[outLen] = sym
                    elseif sym == 256 then
                        break
                    else
                        local li     = sym - 257 + 1
                        local length = LENS_BASE[li] + readBits(LENS_EXTRA[li])
                        local dc     = decodeHuff(FIXED_DIST, 5)
                        local dist   = DIST_BASE[dc+1] + readBits(DIST_EXTRA[dc+1])
                        local from   = outLen - dist + 1
                        for _ = 1, length do
                            outLen = outLen + 1
                            out[outLen] = out[from]
                            from = from + 1
                        end
                    end
                end

            elseif BTYPE == 2 then
                -- Huffman dinámico
                local HLIT  = readBits(5) + 257
                local HDIST = readBits(5) + 1
                local HCLEN = readBits(4) + 4
                local CL_ORDER = {16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15}
                local clens = {}
                for i = 1, 19 do clens[i] = 0 end
                for i = 1, HCLEN do
                    clens[CL_ORDER[i]+1] = readBits(3)
                end
                local clTree, clMax = buildHuffman(clens)

                local lengths = {}
                local total = HLIT + HDIST
                local i = 1
                while i <= total do
                    local sym = decodeHuff(clTree, clMax)
                    if sym < 16 then
                        lengths[i] = sym; i = i + 1
                    elseif sym == 16 then
                        local rep  = readBits(2) + 3
                        local last = lengths[i-1] or 0
                        for _ = 1, rep do lengths[i] = last; i = i + 1 end
                    elseif sym == 17 then
                        local rep = readBits(3) + 3
                        for _ = 1, rep do lengths[i] = 0; i = i + 1 end
                    elseif sym == 18 then
                        local rep = readBits(7) + 11
                        for _ = 1, rep do lengths[i] = 0; i = i + 1 end
                    end
                end

                local llLens, distLens = {}, {}
                for j = 1, HLIT  do llLens[j]  = lengths[j]       or 0 end
                for j = 1, HDIST do distLens[j] = lengths[HLIT+j]  or 0 end
                local llTree,   llMax   = buildHuffman(llLens)
                local distTree, distMax = buildHuffman(distLens)

                while true do
                    local sym = decodeHuff(llTree, llMax)
                    if sym < 256 then
                        outLen = outLen + 1
                        out[outLen] = sym
                    elseif sym == 256 then
                        break
                    else
                        local li     = sym - 257 + 1
                        local length = LENS_BASE[li] + readBits(LENS_EXTRA[li])
                        local dc     = decodeHuff(distTree, distMax)
                        local dist   = DIST_BASE[dc+1] + readBits(DIST_EXTRA[dc+1])
                        local from   = outLen - dist + 1
                        for _ = 1, length do
                            outLen = outLen + 1
                            out[outLen] = out[from]
                            from = from + 1
                        end
                    end
                end
            else
                error("DEFLATE: BTYPE reservado")
            end
        until BFINAL == 1

        return out
    end

    -- ================================================================
    -- PARSER PNG
    -- Devuelve pixels[y][x] = {r,g,b,a} (0-255), width, height
    -- ================================================================
    local function parsePNG(data)
        -- Verificar firma
        local SIG = {137,80,78,71,13,10,26,10}
        for i,v in ipairs(SIG) do
            if data:byte(i) ~= v then
                return nil, "No es un PNG válido (firma incorrecta)"
            end
        end

        -- Helpers
        local function u32(s, i)
            local a,b,c,d = s:byte(i,i+3)
            if not a then return 0 end
            return a*16777216 + b*65536 + c*256 + d
        end

        local pos      = 9
        local width, height, bitDepth, colorType
        local idatData = {}
        local palette  = {}

        -- Leer chunks PNG
        while pos + 8 <= #data do
            local cLen  = u32(data, pos);      pos = pos + 4
            local cType = data:sub(pos, pos+3); pos = pos + 4
            local cData = data:sub(pos, pos + cLen - 1)
            pos = pos + cLen + 4  -- datos + CRC

            if cType == "IHDR" then
                width     = u32(cData, 1)
                height    = u32(cData, 5)
                bitDepth  = cData:byte(9)
                colorType = cData:byte(10)
            elseif cType == "PLTE" then
                for i = 1, #cData, 3 do
                    local r,g,b = cData:byte(i), cData:byte(i+1), cData:byte(i+2)
                    palette[#palette+1] = {r or 0, g or 0, b or 0}
                end
            elseif cType == "IDAT" then
                idatData[#idatData+1] = cData
            elseif cType == "IEND" then
                break
            end
        end

        if not width or not height then
            return nil, "PNG sin IHDR"
        end

        -- Tipos de color soportados
        -- 0=Gray, 2=RGB, 3=Indexed, 4=Gray+A, 6=RGBA
        local chanMap = {[0]=1,[2]=3,[3]=1,[4]=2,[6]=4}
        local channels = chanMap[colorType]
        if not channels then
            return nil, "colorType no soportado: " .. tostring(colorType)
        end

        -- Descomprimir todos los IDAT concatenados
        local compressed = table.concat(idatData)
        local ok, rawData = pcall(inflate, compressed)
        if not ok then
            return nil, "inflate error: " .. tostring(rawData)
        end

        -- bytesPerPixel (para bitDepth=8, lo más común)
        local Bpp = math.max(1, math.floor(channels * bitDepth / 8))

        -- Filtros PNG fila a fila
        local function paeth(a,b,c)
            local p  = a + b - c
            local pa = math.abs(p - a)
            local pb = math.abs(p - b)
            local pc = math.abs(p - c)
            if pa <= pb and pa <= pc then return a
            elseif pb <= pc then return b
            else return c end
        end

        local stride = width * Bpp
        local rows   = {}
        local ri     = 1   -- índice en rawData

        for y = 1, height do
            local ftype = rawData[ri]; ri = ri + 1
            local row   = {}
            local prev  = rows[y-1]

            for x = 1, stride do
                local raw = rawData[ri] or 0; ri = ri + 1
                local a   = (x > Bpp)  and row[x-Bpp]              or 0
                local b   = prev        and (prev[x]   or 0)        or 0
                local c   = (x > Bpp and prev) and (prev[x-Bpp] or 0) or 0
                local val
                if     ftype == 0 then val = raw
                elseif ftype == 1 then val = (raw + a)                         % 256
                elseif ftype == 2 then val = (raw + b)                         % 256
                elseif ftype == 3 then val = (raw + math.floor((a+b)/2))       % 256
                elseif ftype == 4 then val = (raw + paeth(a,b,c))              % 256
                else                   val = raw
                end
                row[x] = val
            end
            rows[y] = row
        end

        -- Construir array de pixels RGBA
        local pixels = {}
        for y = 1, height do
            pixels[y] = {}
            local row  = rows[y]
            for x = 1, width do
                local bi  = (x-1)*Bpp + 1
                local pix
                if colorType == 6 then       -- RGBA
                    pix = {row[bi], row[bi+1], row[bi+2], row[bi+3] or 255}
                elseif colorType == 2 then   -- RGB
                    pix = {row[bi], row[bi+1], row[bi+2], 255}
                elseif colorType == 0 then   -- Grayscale
                    local g = row[bi]
                    pix = {g, g, g, 255}
                elseif colorType == 4 then   -- Grayscale+Alpha
                    local g = row[bi]
                    pix = {g, g, g, row[bi+1] or 255}
                elseif colorType == 3 then   -- Indexed
                    local idx = (row[bi] or 0) + 1
                    local pal = palette[idx] or {255,0,255}
                    pix = {pal[1], pal[2], pal[3], 255}
                else
                    pix = {255,0,255,255}
                end
                pixels[y][x] = pix
            end
        end

        return pixels, width, height
    end

    -- ================================================================
    -- PIXELS → BLOQUES (misma lógica que el HTML)
    -- ================================================================
    local function pixelsToBlocks(pixels, imgW, imgH, res, pSize, thick, doMerge)
        res   = math.max(1, math.floor(res))
        pSize = math.max(0.1, pSize)
        thick = math.max(0.1, thick)

        local BSX, BSY, BSZ = pSize, pSize, thick

        -- Redimensionar al tamaño res×res (nearest neighbor)
        local sw = imgW / res
        local sh = imgH / res
        local grid = {}
        for py = 1, res do
            grid[py] = {}
            local srcY = math.min(imgH, math.max(1, math.floor((py-1)*sh + 0.5) + 1))
            for px = 1, res do
                local srcX = math.min(imgW, math.max(1, math.floor((px-1)*sw + 0.5) + 1))
                grid[py][px] = pixels[srcY][srcX]
            end
        end

        local startX = -(res * BSX) / 2
        local startZ = 0

        local function p3(n) return math.floor(n*1000 + 0.5)/1000 end

        local blocks = {}

        if not doMerge then
            -- Un bloque por pixel visible
            for py = 1, res do
                for px = 1, res do
                    local pix = grid[py][px]
                    if pix and pix[4] >= 13 then
                        local r = p3(pix[1]/255)
                        local g = p3(pix[2]/255)
                        local b = p3(pix[3]/255)
                        local rx = p3(startX + (px-1)*BSX)
                        local ry = p3((res - py)*BSY)
                        blocks[#blocks+1] = {
                            x=rx, y=ry, z=startZ,
                            sx=BSX, sy=BSY, sz=BSZ,
                            r=r, g=g, b=b,
                        }
                    end
                end
            end
        else
            -- Merge greedy: rectangulos del mismo color
            local function colKey(pix)
                if not pix or pix[4] < 13 then return nil end
                return pix[1]..","..pix[2]..","..pix[3]
            end

            local used = {}
            for py = 1, res do
                used[py] = {}
                for px = 1, res do used[py][px] = false end
            end

            for py = 1, res do
                for px = 1, res do
                    local pix = grid[py][px]
                    local key = colKey(pix)
                    if key and not used[py][px] then
                        -- Expandir en X
                        local w = 1
                        while px+w <= res do
                            local np = grid[py][px+w]
                            if not used[py][px+w] and colKey(np) == key then w=w+1
                            else break end
                        end
                        -- Expandir en Y
                        local h = 1
                        local canGrow = true
                        while canGrow and py+h <= res do
                            for kx = px, px+w-1 do
                                local np2 = grid[py+h] and grid[py+h][kx]
                                if used[py+h] and used[py+h][kx] or colKey(np2) ~= key then
                                    canGrow = false; break
                                end
                            end
                            if canGrow then h=h+1 end
                        end
                        -- Marcar usados
                        for yy = py, py+h-1 do
                            for xx = px, px+w-1 do
                                used[yy][xx] = true
                            end
                        end
                        -- Emitir bloque fusionado
                        local r = p3(pix[1]/255)
                        local g = p3(pix[2]/255)
                        local b = p3(pix[3]/255)
                        local cx = p3(startX + (px-1)*BSX + (w*BSX - BSX)/2)
                        local topRow = res - py
                        local botRow = res - (py+h-1)
                        local cy = p3(((topRow+botRow)/2)*BSY)
                        blocks[#blocks+1] = {
                            x=cx, y=cy, z=startZ,
                            sx=p3(w*BSX), sy=p3(h*BSY), sz=BSZ,
                            r=r, g=g, b=b,
                        }
                    end
                end
            end
        end

        return blocks
    end

    -- ================================================================
    -- UI: ScrollingFrame principal
    -- ================================================================
    local PB = mk("ScrollingFrame", Body, {
        Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, BorderSizePixel=0,
        ScrollBarThickness=4, ScrollBarImageColor3=T.accent,
        AutomaticCanvasSize=Enum.AutomaticSize.Y,
        CanvasSize=UDim2.new(0,0,0,0), Visible=false,
    })
    mk("UIListLayout", PB, {Padding=UDim.new(0,6), SortOrder=Enum.SortOrder.LayoutOrder})
    pad(PB, 10,10,10,10)

    local rowOrder = 0
    local function bRow(h)
        rowOrder = rowOrder + 1
        return mk("Frame", PB, {
            Size=UDim2.new(1,0,0,h), BackgroundTransparency=1, LayoutOrder=rowOrder,
        })
    end

    local PURPLE = Color3.fromRGB(170,0,255)

    local cDummy = mk("Part", envF, {
        Size=Vector3.new(4,4,4), Transparency=1, Color=T.accent,
        Anchored=true, CanCollide=false, CanQuery=false,
        Material=Enum.Material.Plastic, Position=Vector3.new(0,-9999,0),
    })
    local ArcAdornee = mk("Part", envF, {
        Size=Vector3.new(12,12,12), Transparency=1, Anchored=true,
        CanCollide=false, CanQuery=false, Position=Vector3.new(0,-9999,0),
    })
    local Handles = mk("Handles", SG, {
        Adornee=cDummy, Style=Enum.HandlesStyle.Movement,
        Color3=PURPLE, Visible=false,
    })
    pcall(function() Handles.AlwaysOnTop = true end)
    local Arc = mk("ArcHandles", SG, {Adornee=ArcAdornee, Color3=PURPLE, Visible=false})
    pcall(function() Arc.AlwaysOnTop = true end)
    local selBox = mk("SelectionBox", SG, {Color3=T.accent, LineThickness=0.04})

    updateHandles = function()
        local can = (cP ~= nil) and not lk and PB.Visible
        if can and tM == "move" then
            Handles.Adornee = cDummy; Handles.Visible = true; Arc.Visible = false
        elseif can and tM == "rotate" then
            Arc.Adornee = ArcAdornee; Arc.Visible = true; Handles.Visible = false
        else
            Handles.Visible = false; Arc.Visible = false
        end
    end

    local function readRealBlockVisual(blockName)
        local folder = userFolder and userFolder(LP.Name)
        if folder then
            for _, p in ipairs(folder:GetChildren()) do
                if p:IsA("BasePart") and p.Name == blockName then
                    return p.Material, p.Color
                end
            end
        end
        local FB = {
            WoodBlock     = {mat=Enum.Material.Wood,        col=Color3.fromRGB(133,94,66)},
            PlasticBlock  = {mat=Enum.Material.Plastic,     col=Color3.fromRGB(163,162,165)},
            MetalBlock    = {mat=Enum.Material.Metal,       col=Color3.fromRGB(155,155,155)},
            GlassBlock    = {mat=Enum.Material.Glass,       col=Color3.fromRGB(160,230,255)},
            IceBlock      = {mat=Enum.Material.Ice,         col=Color3.fromRGB(160,230,255)},
            GrassBlock    = {mat=Enum.Material.Grass,       col=Color3.fromRGB(75,151,75)},
            StoneBlock    = {mat=Enum.Material.Cobblestone, col=Color3.fromRGB(110,110,110)},
            ConcreteBlock = {mat=Enum.Material.Concrete,    col=Color3.fromRGB(140,140,140)},
        }
        local fb = FB[blockName] or {mat=Enum.Material.Plastic, col=Color3.fromRGB(163,162,165)}
        return fb.mat, fb.col
    end

    local function getBI(name)
        local pg = LP:FindFirstChildOfClass("PlayerGui")
        if pg then
            local bf = pg:FindFirstChild("BuildGui")
            if bf then bf=bf:FindFirstChild("InventoryFrame")
            if bf then bf=bf:FindFirstChild("ScrollingFrame")
            if bf then bf=bf:FindFirstChild("BlocksFrame")
            if bf then local tpl=bf:FindFirstChild(name)
            if tpl and tpl:IsA("ImageButton") then return tpl.Image end end end end end
        end
        return ""
    end

    local images       = {}
    local thumbButtons = {}
    local imgGrid, imgInfoLabel

    local function loadImages()
        local files = FSys.ls(IMG_DIR)
        images = {}
        for _, f in ipairs(files) do
            if type(f) == "string" and f:lower():match("%.png$") then
                local name = f:match("([^/\\]+)$") or f
                images[#images+1] = {path=f, name=name}
            end
        end
    end

    refreshGrid = function()
        for _, b in ipairs(thumbButtons) do b:Destroy() end
        thumbButtons = {}
        if #images == 0 then
            local empty = mk("TextLabel", imgGrid, {
                Size=UDim2.new(1,0,0,55),
                Text="Sin imágenes PNG.\nPon archivos .png en:\n"..IMG_DIR,
                TextColor3=T.sub, BackgroundTransparency=1,
                Font=Enum.Font.Gotham, TextSize=10, TextWrapped=true,
            })
            thumbButtons[1] = empty
            return
        end
        for i, img in ipairs(images) do
            local thumb = mk("TextButton", imgGrid, {
                BackgroundColor3=T.card, Text="", LayoutOrder=i, AutoButtonColor=false,
            })
            corner(thumb, 6); stroke(thumb, T.accent, 1)
            local ok, asset = pcall(function() return getcustomasset(img.path) end)
            if ok and asset then
                local il = mk("ImageLabel", thumb, {
                    Size=UDim2.new(1,-4,1,-18), Position=UDim2.new(0,2,0,2),
                    BackgroundTransparency=1, Image=asset, ScaleType=Enum.ScaleType.Fit,
                })
                corner(il, 4)
            else
                mk("TextLabel", thumb, {
                    Size=UDim2.new(1,-4,1,-18), Position=UDim2.new(0,2,0,2),
                    Text="PNG", TextSize=14, BackgroundTransparency=1, TextColor3=T.sub,
                })
            end
            local sn = img.name
            if #sn > 12 then sn = sn:sub(1,10)..".." end
            mk("TextLabel", thumb, {
                Size=UDim2.new(1,-4,0,14), Position=UDim2.new(0,2,1,-16),
                Text=sn, TextColor3=T.sub, BackgroundTransparency=1,
                Font=Enum.Font.Gotham, TextSize=8,
                TextXAlignment=Enum.TextXAlignment.Center,
                TextTruncate=Enum.TextTruncate.AtEnd,
            })
            thumb.MouseButton1Click:Connect(function() selectImage(img) end)
            thumbButtons[#thumbButtons+1] = thumb
        end
    end

    -- ================================================================
    -- SELECCIONAR Y PROCESAR IMAGEN (local, sin servidor)
    -- ================================================================
    local resBox, sizeBox, thicknessBox, mergeBtn  -- declaradas antes de selectImage

    selectImage = function(imgInfo)
        if isProcessing then return end
        isProcessing = true
        imgInfoLabel.Text = "Procesando..."
        imgInfoLabel.TextColor3 = T.warn
        selImage = nil
        hPv()

        task.spawn(function()
            -- Leer archivo
            local data = FSys.rd(imgInfo.path)
            if not data or data == "" then
                imgInfoLabel.Text = "Error: no se pudo leer el archivo"
                imgInfoLabel.TextColor3 = T.danger
                isProcessing = false; return
            end

            -- Leer parámetros actuales
            local res     = math.max(1, math.floor(tonumber(resBox.Text)      or 32))
            local pSize   = math.max(0.1, tonumber(sizeBox.Text)              or 1)
            local thick   = math.max(0.1, tonumber(thicknessBox.Text)         or 2)
            local doMerge = (mergeBtn.Text == "ON")

            -- Parsear PNG
            local ok1, pixels, imgW, imgH = pcall(function()
                return parsePNG(data)
            end)
            -- pcall con múltiples retornos: pixels es el 2do valor
            -- Ajustar porque pcall devuelve (ok, ret1, ret2, ret3)
            -- parsePNG devuelve (pixels, w, h) o (nil, errMsg)
            local pxResult, w, h
            if ok1 then
                -- pixels aquí es en realidad el primer retorno de parsePNG
                pxResult = pixels  -- pixels era el 2do arg de pcall result
                w        = imgW
                h        = imgH
            end

            -- Mejor: llamar directamente con pcall correcto
            local parseOk, parseErr
            pxResult, w, h = nil, nil, nil
            local r1, r2, r3
            parseOk, r1, r2, r3 = pcall(parsePNG, data)
            if not parseOk then
                imgInfoLabel.Text = "Error PNG: " .. tostring(r1)
                imgInfoLabel.TextColor3 = T.danger
                isProcessing = false; return
            end
            -- parsePNG devuelve nil,"msg" si falla
            if not r1 then
                imgInfoLabel.Text = "PNG inválido: " .. tostring(r2)
                imgInfoLabel.TextColor3 = T.danger
                isProcessing = false; return
            end
            pxResult = r1; w = r2; h = r3

            -- Convertir pixels a bloques
            local bOk, bResult = pcall(pixelsToBlocks, pxResult, w, h, res, pSize, thick, doMerge)
            if not bOk then
                imgInfoLabel.Text = "Error bloques: " .. tostring(bResult)
                imgInfoLabel.TextColor3 = T.danger
                isProcessing = false; return
            end

            isProcessing = false

            if #bResult == 0 then
                imgInfoLabel.Text = "Sin píxeles visibles (imagen transparente?)"
                imgInfoLabel.TextColor3 = T.warn
                return
            end

            selImage = {
                name   = imgInfo.name,
                blocks = bResult,
                count  = #bResult,
            }

            imgInfoLabel.Text = string.format("%s — %d bloques", imgInfo.name, selImage.count)
            imgInfoLabel.TextColor3 = T.text

            for idx, tb in ipairs(thumbButtons) do
                if images[idx] and images[idx].path == imgInfo.path then
                    tb.BackgroundColor3 = T.accent
                else
                    tb.BackgroundColor3 = T.card
                end
            end
            mPv()
        end)
    end

    -- ================================================================
    -- SECCIÓN: GALERÍA
    -- ================================================================
    do
        local r = bRow(24)
        lbl(r, "IMÁGENES (PNG)", UDim2.new(1,-28,1,0), UDim2.new(0,0,0,0), T.sub)
        local rBtn = btn(r, "↻", UDim2.new(0,24,0,22), UDim2.new(1,-24,0,1), T.btnAlt)
        rBtn.TextSize = 14
        rBtn.MouseButton1Click:Connect(function() loadImages(); refreshGrid() end)
    end

    do
        local r = bRow(180)
        imgGrid = mk("ScrollingFrame", r, {
            Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, BorderSizePixel=0,
            ScrollBarThickness=3, ScrollBarImageColor3=T.accent,
            AutomaticCanvasSize=Enum.AutomaticSize.Y, CanvasSize=UDim2.new(0,0,0,0),
        })
        mk("UIGridLayout", imgGrid, {
            CellSize=UDim2.new(0.25,-3,0,70),
            CellPadding=UDim2.new(0,4,0,4),
            SortOrder=Enum.SortOrder.LayoutOrder,
        })
        pad(imgGrid, 2,2,2,2)
    end

    do
        local r = bRow(20)
        imgInfoLabel = lbl(r, "Selecciona una imagen", UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), T.sub)
        imgInfoLabel.Font = Enum.Font.Gotham
        imgInfoLabel.TextSize = 10
        imgInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
    end

    -- ================================================================
    -- SECCIÓN: SELECTOR DE MATERIAL
    -- ================================================================
    local matPickOv, matPickBtn, mLabelRef, mIconRef

    local function updMatBtn(nm, iconId)
        selBlockName = nm
        if mLabelRef then mLabelRef.Text = nm end
        if mIconRef  then mIconRef.Image  = iconId or DEF_IMG end
        task.spawn(function()
            local mat, col = readRealBlockVisual(nm)
            sBMat = mat; sBCol = col; mPv()
        end)
    end

    do
        local r = bRow(28)
        matPickBtn = mk("TextButton", r, {
            Size=UDim2.new(1,0,0,24), Position=UDim2.new(0,0,0.5,-12),
            BackgroundColor3=T.input, BorderSizePixel=0,
            Font=Enum.Font.GothamSemibold, TextSize=10,
            Text="", TextColor3=T.text,
            TextXAlignment=Enum.TextXAlignment.Left,
        })
        corner(matPickBtn, 6)
        mIconRef = mk("ImageLabel", matPickBtn, {
            Size=UDim2.new(0,20,0,20), Position=UDim2.new(0,4,0.5,-10),
            BackgroundTransparency=1,
        })
        mLabelRef = mk("TextLabel", matPickBtn, {
            Size=UDim2.new(1,-32,1,0), Position=UDim2.new(0,28,0,0),
            BackgroundTransparency=1, Font=Enum.Font.GothamSemibold,
            TextSize=10, TextColor3=T.text,
            TextXAlignment=Enum.TextXAlignment.Left,
            Text=selBlockName,
        })

        -- Overlay para elegir bloque
        matPickOv = mk("Frame", ENV.Win, {
            Size=UDim2.new(1,0,1,0), BackgroundColor3=Color3.new(0,0,0),
            BackgroundTransparency=0.35, BorderSizePixel=0,
            Visible=false, ZIndex=60,
        })
        mk("TextButton", matPickOv, {
            Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
            Text="", ZIndex=60, AutoButtonColor=false,
        }).MouseButton1Click:Connect(function() matPickOv.Visible = false end)

        local pBox = mk("Frame", matPickOv, {
            Size=UDim2.new(1,-20,0.85,0),
            AnchorPoint=Vector2.new(0.5,0.5),
            Position=UDim2.new(0.5,0,0.5,0),
            BackgroundColor3=T.panel, BorderSizePixel=0, ZIndex=61,
        })
        corner(pBox, 10)
        mk("TextLabel", pBox, {
            Size=UDim2.new(1,0,0,28), BackgroundTransparency=1,
            Text="ELEGIR BLOQUE", TextColor3=T.text,
            Font=Enum.Font.GothamBold, TextSize=12,
            TextXAlignment=Enum.TextXAlignment.Center, ZIndex=62,
        })
        local pScroll = mk("ScrollingFrame", pBox, {
            Size=UDim2.new(1,-8,1,-36), Position=UDim2.new(0,4,0,30),
            BackgroundTransparency=1, BorderSizePixel=0,
            ScrollBarThickness=4, ScrollBarImageColor3=T.accent,
            AutomaticCanvasSize=Enum.AutomaticSize.Y, ZIndex=62,
        })
        mk("UIListLayout", pScroll, {Padding=UDim.new(0,4), SortOrder=Enum.SortOrder.LayoutOrder})
        pad(pScroll, 4,4,4,4)

        local function popPicker()
            for _, c in ipairs(pScroll:GetChildren()) do
                if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
            end
            local df = LP:FindFirstChild("Data"); if not df then return end
            local order = 0
            for _, item in ipairs(df:GetChildren()) do
                if item:IsA("ValueBase") and item.Name:sub(-5) == "Block" then
                    local qty = tonumber(item.Value) or 0
                    if qty > 0 then
                        order = order + 1
                        local fi = getBI(item.Name)
                        local row = mk("TextButton", pScroll, {
                            Size=UDim2.new(1,0,0,36), BackgroundColor3=T.card,
                            BorderSizePixel=0, Text="", LayoutOrder=order, ZIndex=63,
                        })
                        corner(row, 6)
                        mk("ImageLabel", row, {
                            Size=UDim2.new(0,26,0,26), Position=UDim2.new(0,5,0.5,-13),
                            BackgroundTransparency=1, ZIndex=64,
                            Image=fi~="" and fi or DEF_IMG,
                        })
                        mk("TextLabel", row, {
                            Size=UDim2.new(1,-80,1,0), Position=UDim2.new(0,36,0,0),
                            BackgroundTransparency=1, Font=Enum.Font.GothamSemibold,
                            TextSize=11, TextColor3=T.text,
                            TextXAlignment=Enum.TextXAlignment.Left,
                            Text=item.Name, ZIndex=64,
                        })
                        mk("TextLabel", row, {
                            Size=UDim2.new(0,70,1,0), Position=UDim2.new(1,-74,0,0),
                            BackgroundTransparency=1, Font=Enum.Font.GothamBold,
                            TextSize=11, TextColor3=T.sub,
                            TextXAlignment=Enum.TextXAlignment.Right,
                            Text="x"..item.Value, ZIndex=64,
                        })
                        local ci = fi
                        row.MouseButton1Click:Connect(function()
                            updMatBtn(item.Name, ci)
                            matPickOv.Visible = false
                        end)
                    end
                end
            end
        end

        matPickBtn.MouseButton1Click:Connect(function() popPicker(); matPickOv.Visible = true end)

        task.defer(function()
            task.wait(0.8)
            local df = LP:FindFirstChild("Data"); if not df then return end
            local pb = df:FindFirstChild("PlasticBlock")
            if pb and (tonumber(pb.Value) or 0) > 0 then
                updMatBtn("PlasticBlock", getBI("PlasticBlock"))
            else
                for _, item in ipairs(df:GetChildren()) do
                    if item:IsA("ValueBase") and item.Name:sub(-5) == "Block"
                    and (tonumber(item.Value) or 0) > 0 then
                        updMatBtn(item.Name, getBI(item.Name)); break
                    end
                end
            end
        end)
    end

    -- ================================================================
    -- SECCIÓN: CONTROLES NUMÉRICOS
    -- ================================================================
    local function cleanNum(t)
        local out = {}; local dotUsed = false
        for i = 1, #t do
            local c = t:sub(i,i)
            if c:match("%d") then out[#out+1] = c
            elseif c == "-" and i == 1 then out[#out+1] = c
            elseif c == "." and not dotUsed then out[#out+1] = c; dotUsed = true end
        end
        return table.concat(out)
    end

    local function bindHold(b, fn)
        local h = false
        local function go()
            if h then return end; h = true; fn()
            task.spawn(function()
                local d = 0.35; task.wait(d)
                while h do fn(); task.wait(d); d = math.max(0.03, d*0.75) end
            end)
        end
        local function stop() h = false end
        b.MouseButton1Down:Connect(go)
        b.MouseButton1Up:Connect(stop)
        b.MouseLeave:Connect(stop)
    end

    local function mkNumRow(row, label, default, step, minVal)
        lbl(row, label, UDim2.new(0,72,1,0), UDim2.new(0,0,0,0), T.sub)
        local bl = btn(row, "-", UDim2.new(0,24,0,24), UDim2.new(0,76,0,0), T.btnAlt)
        local bx = box(row, UDim2.new(1,-132,0,24), UDim2.new(0,104,0,0), default)
        bx.TextXAlignment = Enum.TextXAlignment.Center
        local br = btn(row, "+", UDim2.new(0,24,0,24), UDim2.new(1,-24,0,0), T.btnAlt)
        local decimal = (step < 1) or (minVal and minVal < 1)
        local function fmt(n)
            if minVal then n = math.max(minVal, n) end
            if decimal then
                if n == math.floor(n) then return tostring(math.floor(n))
                else return string.format("%.2f", n) end
            else return tostring(math.floor(n+0.5)) end
        end
        local guard = false
        bx:GetPropertyChangedSignal("Text"):Connect(function()
            if guard then return end
            local c = cleanNum(bx.Text)
            if c ~= bx.Text then guard=true; bx.Text=c; guard=false end
            mPv()
        end)
        bx.FocusLost:Connect(function()
            local v = tonumber(bx.Text)
            if not v or bx.Text=="" then
                guard=true; bx.Text=fmt(tonumber(default) or 0); guard=false
            elseif minVal and v < minVal then
                guard=true; bx.Text=fmt(minVal); guard=false
            end
            mPv()
        end)
        bindHold(bl, function()
            local cur = tonumber(bx.Text) or (minVal or 0)
            local nv = math.max(minVal or -math.huge, cur - step)
            guard=true; bx.Text=fmt(nv); guard=false; mPv()
        end)
        bindHold(br, function()
            local cur = tonumber(bx.Text) or (minVal or 0)
            local nv = cur + step
            if minVal then nv = math.max(minVal, nv) end
            guard=true; bx.Text=fmt(nv); guard=false; mPv()
        end)
        return bx
    end

    do local r = bRow(24); resBox        = mkNumRow(r, "Resolución",  "32", 1,   1  ) end
    do local r = bRow(24); sizeBox       = mkNumRow(r, "Tam. Pixel",  "1",  0.1, 0.1) end
    do local r = bRow(24); thicknessBox  = mkNumRow(r, "Grosor",      "2",  0.1, 0.1) end

    do
        local r = bRow(24)
        lbl(r, "Unir colores", UDim2.new(0,100,1,0), UDim2.new(0,0,0,0), T.sub)
        mergeBtn = btn(r, "OFF", UDim2.new(0,50,0,22), UDim2.new(1,-54,0,1), T.btnAlt)
        local function refM()
            local on = (mergeBtn.Text == "ON")
            mergeBtn.BackgroundColor3 = on and WHITE or T.btnAlt
            mergeBtn.TextColor3       = on and BLACK or T.text
        end
        mergeBtn.MouseButton1Click:Connect(function()
            mergeBtn.Text = (mergeBtn.Text == "ON") and "OFF" or "ON"
            refM()
        end)
    end

    -- Botón re-procesar con parámetros actuales
    do
        local r = bRow(26)
        local regenBtn = btn(r, "⟳ Re-procesar con parámetros actuales", UDim2.new(1,0,0,24), nil, T.btnAlt)
        regenBtn.TextSize = 10
        regenBtn.MouseButton1Click:Connect(function()
            if not selImage then
                imgInfoLabel.Text = "Selecciona una imagen primero"
                imgInfoLabel.TextColor3 = T.danger
                return
            end
            for _, img in ipairs(images) do
                if img.name == selImage.name then selectImage(img); return end
            end
        end)
    end

    -- ================================================================
    -- SECCIÓN: POSICIÓN Y HANDLES
    -- ================================================================
    local BtnBldC, BtnBldS
    local bCZ = true

    local function rfBP()
        BtnBldC.BackgroundColor3 = bCZ and WHITE or T.btnAlt
        BtnBldC.TextColor3       = bCZ and BLACK or T.text
        BtnBldS.BackgroundColor3 = (not bCZ) and WHITE or T.btnAlt
        BtnBldS.TextColor3       = (not bCZ) and BLACK or T.text
    end

    local yOffset = 3
    local function centerOnCZ()
        local z = closestZone(myRefPos())
        if z then
            baseCPos = z.Position + Vector3.new(0, z.Size.Y/2 + 0.5, 0)
            cP = baseCPos + Vector3.new(0, yOffset, 0)
            sR = CFrame.identity; hR = false
            cDummy.CFrame    = CFrame.new(cP)
            ArcAdornee.CFrame = CFrame.new(cP)
            updateHandles(); mPv(); return true
        end
        return false
    end

    do
        local r = bRow(28)
        BtnBldC = btn(r, "Centro zona",   UDim2.new(0.5,-3,1,0), UDim2.new(0,0,0,0),   WHITE)
        BtnBldC.TextColor3 = BLACK
        BtnBldS = btn(r, "Sel. Posición", UDim2.new(0.5,-3,1,0), UDim2.new(0.5,3,0,0), T.btnAlt)
        BtnBldC.MouseButton1Click:Connect(function() bCZ=true; rfBP(); centerOnCZ() end)
        local bSel2 = false
        BtnBldS.MouseButton1Click:Connect(function()
            if bSel2 or lk then return end; bSel2=true; bCZ=false; rfBP()
            BtnBldS.Text = "Haz clic..."
            local rc, cc
            rc = RunService.RenderStepped:Connect(function() selBox.Adornee = Mouse.Target end)
            cc = Mouse.Button1Down:Connect(function()
                local t = Mouse.Target
                if t and t:IsA("BasePart") and not t:IsDescendantOf(SG) then
                    baseCPos = t.Position
                    cP = baseCPos + Vector3.new(0, yOffset, 0)
                    sR = CFrame.identity; hR = false
                    cDummy.CFrame    = CFrame.new(cP)
                    ArcAdornee.CFrame = CFrame.new(cP)
                    rc:Disconnect(); cc:Disconnect()
                    selBox.Adornee = nil; bSel2 = false
                    BtnBldS.Text = "Sel. Posición"
                    updateHandles(); mPv()
                end
            end)
        end)
    end
    rfBP()

    -- Herramientas mover/rotar
    local bMove, bRotT, moveStepBox, rotStepBox

    local function rfT()
        bMove.BackgroundColor3 = (tM=="move")   and T.btn or T.btnAlt
        bRotT.BackgroundColor3 = (tM=="rotate") and T.btn or T.btnAlt
        updateHandles()
    end

    local function stepVal(bx)
        local v = tonumber(bx and bx.Text)
        return (v and v >= 0) and v or 0
    end

    local function mkStepBox(parent, size, pos, default)
        local bx = box(parent, size, pos, default)
        bx.TextXAlignment = Enum.TextXAlignment.Center
        local guard = false
        bx:GetPropertyChangedSignal("Text"):Connect(function()
            if guard then return end
            local c = cleanNum(bx.Text)
            if c ~= bx.Text then guard=true; bx.Text=c; guard=false end
        end)
        bx.FocusLost:Connect(function()
            local v = tonumber(bx.Text)
            if not v or v < 0 then guard=true; bx.Text="0"; guard=false end
        end)
        return bx
    end

    do
        local r = bRow(26)
        bMove = btn(r, "", UDim2.new(0,44,0,26), UDim2.new(0,0,0,0), T.btn)
        mk("ImageLabel", bMove, {
            Size=UDim2.new(0,18,0,18), Position=UDim2.new(0.5,-9,0.5,-9),
            BackgroundTransparency=1, Image=ICON_MOVE,
        })
        moveStepBox = mkStepBox(r, UDim2.new(0.5,-51,0,26), UDim2.new(0,48,0,0), "1")
        bRotT = btn(r, "", UDim2.new(0,44,0,26), UDim2.new(0.5,3,0,0), T.btnAlt)
        mk("ImageLabel", bRotT, {
            Size=UDim2.new(0,18,0,18), Position=UDim2.new(0.5,-9,0.5,-9),
            BackgroundTransparency=1, Image=ICON_ROT,
        })
        rotStepBox = mkStepBox(r, UDim2.new(0.5,-51,0,26), UDim2.new(0.5,51,0,0), "15")
        bMove.MouseButton1Click:Connect(function() tM="move";   rfT() end)
        bRotT.MouseButton1Click:Connect(function() tM="rotate"; rfT() end)
    end

    -- Drag handles
    do
        local drag2, savedCam, origDP, origBaseCPos = false,nil,nil,nil
        Handles.MouseButton1Down:Connect(function()
            if not PB.Visible or lk or not cP then return end
            drag2=true; origDP=cDummy.Position; origBaseCPos=baseCPos
            savedCam=Camera.CFrame; Camera.CameraType=Enum.CameraType.Scriptable
        end)
        Handles.MouseDrag:Connect(function(face, dist)
            if not PB.Visible or not drag2 or not origDP then return end
            local st = stepVal(moveStepBox)
            local d  = (st>0) and (math.floor(dist/st+0.5)*st) or dist
            local mv = cDummy.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face))*d
            cP = origDP + mv
            if origBaseCPos then baseCPos = origBaseCPos + mv end
            cDummy.Position = cP; mPv()
        end)
        Handles.MouseButton1Up:Connect(function()
            if not PB.Visible then return end
            drag2=false; savedCam=nil; Camera.CameraType=Enum.CameraType.Custom
        end)

        local arcDrag, arcStartRot, arcSavedCam = false,nil,nil
        Arc.MouseButton1Down:Connect(function()
            if lk or not cP then return end
            arcDrag=true; arcStartRot=sR
            arcSavedCam=Camera.CFrame; Camera.CameraType=Enum.CameraType.Scriptable
        end)
        Arc.MouseDrag:Connect(function(axis, relAngle)
            if not arcDrag then return end
            local av = (axis==Enum.Axis.X and Vector3.xAxis)
                    or (axis==Enum.Axis.Y and Vector3.yAxis)
                    or Vector3.zAxis
            local st = stepVal(rotStepBox)
            local snap = (st>0) and math.rad(math.floor(math.deg(relAngle)/st+0.5)*st) or relAngle
            sR = arcStartRot * CFrame.fromAxisAngle(av, snap); hR = true
            if cP then cDummy.CFrame = CFrame.new(cP)*sR end; mPv()
        end)
        Arc.MouseButton1Up:Connect(function()
            arcDrag=false; arcSavedCam=nil
            Camera.CameraType=Enum.CameraType.Custom
        end)

        RunService.RenderStepped:Connect(function()
            if drag2   and savedCam   then Camera.CFrame = savedCam    end
            if arcDrag and arcSavedCam then Camera.CFrame = arcSavedCam end
            if cP and hR then cDummy.CFrame = CFrame.new(cP)*sR
            elseif cP    then cDummy.Position = cP end
            if cP then ArcAdornee.CFrame = CFrame.new(cP)*(hR and sR or CFrame.identity)
            else       ArcAdornee.Position = Vector3.new(0,-9999,0) end
            if PB.Visible and cP and not lk then
                if tM=="move" then
                    if Handles.Adornee ~= cDummy then Handles.Adornee = cDummy end
                    Handles.Visible = true; Arc.Visible = false
                elseif tM=="rotate" then
                    if Arc.Adornee ~= ArcAdornee then Arc.Adornee = ArcAdornee end
                    Arc.Visible = true; Handles.Visible = false
                end
            elseif not PB.Visible then
                Handles.Visible = false; Arc.Visible = false
            end
        end)
    end

    -- ================================================================
    -- PREVIEW
    -- ================================================================
    local pp = {}

    hPv = function()
        for _, p in ipairs(pp) do
            p.Transparency = 1
            p.Size = Vector3.new(0.05,0.05,0.05)
        end
    end

    local pD = false
    mPv = function() pD = true end

    local function generatePlan()
        if not selImage or not cP then return {} end
        local cx, cy, cz = cP.X, cP.Y, cP.Z
        local plan = {}
        for _, blk in ipairs(selImage.blocks) do
            local localPos = Vector3.new(blk.x, blk.y, blk.z)
            local finalPos, finalCF
            if hR then
                local cf = CFrame.new(cx,cy,cz) * sR * CFrame.new(localPos)
                finalPos = cf.Position
                finalCF  = CFrame.new(finalPos) * sR
            else
                finalPos = Vector3.new(cx+blk.x, cy+blk.y, cz+blk.z)
                finalCF  = CFrame.new(finalPos)
            end
            plan[#plan+1] = {
                cframe = finalCF,
                size   = Vector3.new(blk.sx, blk.sy, blk.sz),
                color  = Color3.new(blk.r, blk.g, blk.b),
            }
        end
        return plan
    end

    local function rnP(plan)
        local maxP   = 2500
        local stride = (#plan > maxP) and math.ceil(#plan/maxP) or 1
        local n = 0
        for i = 1, #plan, stride do
            n = n + 1
            local p = pp[n]
            if not p then
                p = mk("Part", prevF, {
                    Anchored=true, CanCollide=false, CanQuery=false,
                    CanTouch=false, CastShadow=false,
                })
                pp[n] = p
            end
            p.Size         = plan[i].size
            p.CFrame       = plan[i].cframe
            p.Material     = sBMat
            p.Color        = plan[i].color or sBCol
            p.Transparency = pA
        end
        for i = n+1, #pp do
            pp[i].Transparency = 1
            pp[i].Size = Vector3.new(0.05,0.05,0.05)
        end
        return #plan, (stride > 1)
    end

    local function dPv()
        if not PB.Visible then hPv(); return end
        if not cP or not pOn or lk or not selImage then hPv(); return end
        local plan = generatePlan()
        if not plan or #plan == 0 then hPv(); return end
        -- Bounding box para cDummy
        local minv = Vector3.new( math.huge, math.huge, math.huge)
        local maxv = Vector3.new(-math.huge,-math.huge,-math.huge)
        for _, seg in ipairs(plan) do
            local hS = seg.size/2
            local p  = seg.cframe.Position
            minv = Vector3.new(math.min(minv.X,p.X-hS.X), math.min(minv.Y,p.Y-hS.Y), math.min(minv.Z,p.Z-hS.Z))
            maxv = Vector3.new(math.max(maxv.X,p.X+hS.X), math.max(maxv.Y,p.Y+hS.Y), math.max(maxv.Z,p.Z+hS.Z))
        end
        if minv.X ~= math.huge then
            local sz = maxv - minv
            cDummy.Size = Vector3.new(math.clamp(sz.X,4,200), math.clamp(sz.Y,4,200), math.clamp(sz.Z,4,200))
        else cDummy.Size = Vector3.new(4,4,4) end
        ArcAdornee.Size = cDummy.Size
        local total, sampled = rnP(plan)
        if sampled then setStat(("preview %d (muestra)"):format(total), T.warn)
        else        setStat(("preview %d bloques"):format(total), T.sub) end
    end

    RunService.Heartbeat:Connect(function()
        if pD then pD=false; dPv() end
    end)

    -- ================================================================
    -- SECCIÓN: VISTA PREVIA + CONSTRUIR
    -- ================================================================
    local BPr, BB, SL

    setStat = function(t, col)
        if SL then SL.Text=t; SL.TextColor3=col or T.text end
    end

    do
        local r = bRow(32)
        BPr = btn(r, "Vista previa: On", UDim2.new(1,-80,1,0), nil, WHITE)
        BPr.TextColor3 = BLACK
        local pAF = mk("Frame", r, {
            Size=UDim2.new(0,76,1,0), Position=UDim2.new(1,-76,0,0),
            BackgroundColor3=T.btnAlt, BorderSizePixel=0,
        })
        corner(pAF, 6)
        local pAD  = btn(pAF, "-", UDim2.new(0,22,1,0), UDim2.new(0,0,0,0),   T.btnAlt)
        local pALbl = lbl(pAF, math.floor(pA*100).."%", UDim2.new(0,28,1,0), UDim2.new(0,22,0,0), T.text)
        pALbl.TextXAlignment=Enum.TextXAlignment.Center; pALbl.Font=Enum.Font.GothamBold; pALbl.TextSize=10
        local pAU  = btn(pAF, "+", UDim2.new(0,22,1,0), UDim2.new(1,-22,0,0), T.btnAlt)
        local function setAlpha(v)
            pA = math.clamp(v,0,0.95)
            pALbl.Text = math.floor(pA*100).."%"
            mPv()
        end
        pAD.MouseButton1Click:Connect(function() setAlpha(pA-0.10) end)
        pAU.MouseButton1Click:Connect(function() setAlpha(pA+0.10) end)
        BPr.MouseButton1Click:Connect(function()
            if lk then return end
            pOn = not pOn
            BPr.Text = pOn and "Vista previa: On" or "Vista previa: Off"
            BPr.BackgroundColor3 = pOn and WHITE or T.btnAlt
            BPr.TextColor3       = pOn and BLACK or T.text
            mPv()
        end)
    end

    do
        local r = bRow(32)
        BB = btn(r, "Construir", UDim2.new(1,0,1,0), nil, WHITE)
        BB.TextColor3 = BLACK
        SL = mk("TextLabel", BB, {
            Size=UDim2.new(0,100,0,12), Position=UDim2.new(1,-104,1,-16),
            Text="listo", TextColor3=Color3.new(0,0,0),
            BackgroundTransparency=1, Font=Enum.Font.Gotham,
            TextSize=9, TextXAlignment=Enum.TextXAlignment.Right,
        })
    end

    -- ================================================================
    -- CONSTRUCCIÓN
    -- ================================================================
    local blockQueue = {}; local blockConn = nil

    local function hookFolder(folder)
        if blockConn then blockConn:Disconnect(); blockConn=nil end
        blockQueue = {}
        if folder then
            blockConn = folder.ChildAdded:Connect(function(c) blockQueue[#blockQueue+1]=c end)
        end
    end

    local function popBlock(timeout)
        local t0 = tick()
        while #blockQueue == 0 do
            if bS.cancel then return nil end
            if tick()-t0 > timeout then return nil end
            task.wait()
        end
        return table.remove(blockQueue, 1)
    end

    local function setLocked(s)
        lk = s
        for _, b in ipairs(thumbButtons) do
            if b:IsA("GuiButton") then b.Active = not s end
        end
        updateHandles()
    end

    local function iniciarConstruccion()
        if gbRunRef.value then setStat("ya hay construcción en curso", T.danger); return end
        if not cP        then setStat("selecciona un centro primero", T.danger); return end
        if not selImage  then setStat("selecciona una imagen primero", T.danger); return end

        local sharing    = isSharing()
        local activeData = getActiveData()
        local invItem    = activeData and activeData:FindFirstChild(selBlockName)
        if not invItem or invItem.Value <= 0 then
            setStat("material no válido / sin stock", T.danger); return
        end
        local bTool = getActiveTool("BuildingTool")
        if not bTool then setStat("falta BuildingTool", T.danger); return end
        local sTool = getActiveTool("ScalingTool")
        local pTool = getActiveTool("PaintingTool")

        bS.running=true; bS.cancel=false; gbRunRef.value=true
        BB.Text="Cancelar"; BB.BackgroundColor3=T.danger; BB.TextColor3=BLACK
        setLocked(true); hPv()

        local ok2, err = pcall(function()
            local plan  = generatePlan()
            local total = #plan
            if total == 0 then error("plan vacío") end

            if not sharing then
                equipTool(bTool); equipTool(sTool)
                if pTool then equipTool(pTool) end
            end

            local bRF = bTool:FindFirstChild("RF")
            local sRF = sTool and sTool:FindFirstChild("RF")
            local pRF = pTool and pTool:FindFirstChild("RF")
            if not bRF then error("BuildingTool sin RF") end

            local folder = userFolder(LP.Name)
            hookFolder(folder)

            local placed = 0
            local pBl    = {}

            local function placeOne(seg)
                local ret = bRF:InvokeServer(selBlockName, invItem.Value, nil, seg.cframe, true, seg.cframe, false)
                local blk
                if typeof(ret)=="Instance" and ret:IsA("BasePart") then blk=ret
                else blk=popBlock(3) end
                if blk and sRF then
                    pcall(function() sRF:InvokeServer(blk, seg.size, seg.cframe) end)
                end
                return blk
            end

            local WORKERS = sharing and 15 or 50
            local nextIdx = 1; local active = WORKERS

            local function worker()
                while true do
                    if bS.cancel then break end
                    if invItem.Value <= 0 then break end
                    local i = nextIdx; nextIdx = nextIdx+1
                    if i > total then break end
                    if not folder or folder.Parent == nil then
                        folder = userFolder(LP.Name); hookFolder(folder)
                    end
                    local blk = placeOne(plan[i])
                    if blk then
                        placed = placed+1
                        pBl[#pBl+1] = {block=blk, color=plan[i].color}
                    end
                end
                active = active-1
            end

            for _ = 1, WORKERS do task.spawn(worker) end
            while active > 0 do
                setStat(("Construyendo %d/%d"):format(placed,total), T.warn)
                task.wait(0.03)
            end
            if blockConn then blockConn:Disconnect(); blockConn=nil end

            if not bS.cancel and #pBl > 0 and pRF then
                setStat(("Pintando %d bloques..."):format(#pBl), T.warn)
                local paintData = {}
                for _, item in ipairs(pBl) do
                    paintData[#paintData+1] = {item.block, item.color}
                end
                paintBatch(pRF, paintData)
            end

            if bS.cancel then
                setStat(("Cancelado (%d colocados)"):format(placed), T.danger)
            else
                setStat(("listo — %d/%d"):format(placed,total), T.ok)
            end
        end)

        if blockConn then blockConn:Disconnect(); blockConn=nil end
        if not ok2   then setStat("error: "..tostring(err), T.danger) end

        local hum = LP.Character and LP.Character:FindFirstChild("Humanoid")
        if hum then pcall(function() hum:UnequipTools() end) end

        bS.running=false; bS.cancel=false; gbRunRef.value=false
        BB.Text="Construir"; BB.BackgroundColor3=WHITE; BB.TextColor3=BLACK
        setLocked(false)
        if pOn then mPv() end
    end

    BB.MouseButton1Click:Connect(function()
        if bS.running then bS.cancel=true; setStat("cancelando...", T.danger); return end
        task.spawn(iniciarConstruccion)
    end)

    -- ================================================================
    -- RE-CENTRAR AL CAMBIAR DE ZONA / PERSONAJE
    -- ================================================================
    local function waitAndRecenter()
        task.spawn(function()
            for _ = 1, 20 do
                task.wait(0.3)
                local ok, ref = pcall(myRefPos)
                if ok and ref and ref.Y > -100 then
                    if centerOnCZ() then bCZ=true; rfBP(); needsRecenter=false; return end
                end
            end
            needsRecenter = true
        end)
    end

    LP:GetPropertyChangedSignal("Team"):Connect(function()
        if PB.Visible then waitAndRecenter() else needsRecenter=true end
    end)
    LP.CharacterAdded:Connect(function(char)
        local hrp = char:WaitForChild("HumanoidRootPart",8)
        if not hrp then return end
        task.wait(0.2)
        if PB.Visible then waitAndRecenter() else needsRecenter=true end
    end)
    PB:GetPropertyChangedSignal("Visible"):Connect(function()
        if PB.Visible and needsRecenter then needsRecenter=false; waitAndRecenter() end
    end)

    -- ================================================================
    -- INICIO
    -- ================================================================
    rfT(); rfBP()
    loadImages(); refreshGrid()
    task.defer(function() task.wait(0.3); rfT() end)
    task.spawn(function()
        task.wait(1)
        if centerOnCZ() then bCZ=true; rfBP() end
    end)

    return {
        page        = PB,
        hidePreview = hPv,
        markPreview = mPv,
        handles     = Handles,
        arc         = Arc,
        arcAdornee  = ArcAdornee,
        cDummy      = cDummy,
    }
end

return ImagenesModule
