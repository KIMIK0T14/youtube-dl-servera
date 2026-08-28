-- imagenes.lua
-- Módulo: Convertir imágenes a bloques (Usando Servidor Externo)

local ImagenesModule = {}

-- ============================================================
-- INICIALIZACIÓN DEL MÓDULO
-- ============================================================

function ImagenesModule.init(ENV)
    local mk = ENV.mk; local corner = ENV.corner; local stroke = ENV.stroke; local pad = ENV.pad
    local lbl = ENV.lbl; local box = ENV.box; local btn = ENV.btn; local T = ENV.T
    local SG = ENV.SG; local Body = ENV.Body; local openCP = ENV.openCP
    local RunService = ENV.RunService; local Camera = ENV.Camera; local Mouse = ENV.Mouse
    local LP = ENV.LP; local equipTool = ENV.equipTool
    local userFolder = ENV.userFolder; local isSharing = ENV.isSharing
    local getActiveData = ENV.getActiveData; local getActiveTool = ENV.getActiveTool
    local paintBatch = ENV.paintBatch; local closestZone = ENV.closestZone; local myRefPos = ENV.myRefPos
    local FSys = ENV.FSys; local prevF = ENV.prevF; local envF = ENV.envF
    local ICON_MOVE = ENV.ICON_MOVE; local ICON_ROT = ENV.ICON_ROT
    local gbRunRef = ENV.gbRunning
    local HttpService = ENV.HttpService

    -- CONFIGURACIÓN DEL SERVIDOR
    -- Si juegas en PC, usa "http://localhost:5000/process"
    -- Si juegas en móvil, sube el server.py a Replit y pon la URL aquí:
    local SERVER_URL = "https://image-blocks-api--aiko8387.replit.app/process"
    local IMG_DIR = "Build a Boat For Treasure/images"
    FSys.mkf(IMG_DIR)

    local WHITE = Color3.fromRGB(255, 255, 255)
    local BLACK = Color3.fromRGB(0, 0, 0)
    local DEF_IMG = "rbxassetid://12328114032"

    local updateHandles, mPv, hPv, setStat, selectImage, refreshGrid

    local selImage = nil
    local isProcessing = false
    local selBlockName = "PlasticBlock"
    local selColor = Color3.fromRGB(255, 255, 255)
    local useColor = false
    local pOn = true
    local pA = 0.55
    local cP = nil
    local baseCPos = nil
    local tM = "move"
    local sR = CFrame.identity
    local hR = false
    local bS = {running = false, cancel = false}
    local needsRecenter = false
    local sBMat = Enum.Material.Plastic
    local sBCol = Color3.fromRGB(163, 162, 165)
    local lk = false

    local PB = mk("ScrollingFrame", Body, {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 4, ScrollBarImageColor3 = T.accent,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0), Visible = false
    })
    mk("UIListLayout", PB, {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})
    pad(PB, 10, 10, 10, 10)

    local rowBuild = {}
    local function bRow(h, visFn)
        local f = mk("Frame", PB, {Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1, LayoutOrder = #rowBuild + 1})
        rowBuild[#rowBuild + 1] = {frame = f, vis = visFn}
        return f
    end

    local PURPLE = Color3.fromRGB(170, 0, 255)
    local cDummy = mk("Part", envF, {
        Size = Vector3.new(4, 4, 4), Transparency = 1, Color = T.accent,
        Anchored = true, CanCollide = false, CanQuery = false,
        Material = Enum.Material.Plastic, Position = Vector3.new(0, -9999, 0)
    })
    local ArcAdornee = mk("Part", envF, {
        Size = Vector3.new(12, 12, 12), Transparency = 1, Anchored = true,
        CanCollide = false, CanQuery = false, Position = Vector3.new(0, -9999, 0)
    })
    local Handles = mk("Handles", SG, {
        Adornee = cDummy, Style = Enum.HandlesStyle.Movement,
        Color3 = PURPLE, Visible = false
    })
    pcall(function() Handles.AlwaysOnTop = true end)
    local Arc = mk("ArcHandles", SG, {Adornee = ArcAdornee, Color3 = PURPLE, Visible = false})
    pcall(function() Arc.AlwaysOnTop = true end)
    local selBox = mk("SelectionBox", SG, {Color3 = T.accent, LineThickness = 0.04})

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
                if p:IsA("BasePart") and p.Name == blockName then return p.Material, p.Color end
            end
        end
        local function searchR(parent, depth)
            if depth > 4 then return nil, nil end
            for _, inst in ipairs(parent:GetChildren()) do
                if inst:IsA("BasePart") and inst.Name == blockName then return inst.Material, inst.Color end
                local m, c = searchR(inst, depth + 1); if m then return m, c end
            end
            return nil, nil
        end
        local mat, col = searchR(game:GetService("Workspace"), 0)
        if mat then return mat, col end
        local FB = {
            WoodBlock = {mat = Enum.Material.Wood, col = Color3.fromRGB(133, 94, 66)},
            PlasticBlock = {mat = Enum.Material.Plastic, col = Color3.fromRGB(163, 162, 165)},
            MetalBlock = {mat = Enum.Material.Metal, col = Color3.fromRGB(155, 155, 155)},
            GlassBlock = {mat = Enum.Material.Glass, col = Color3.fromRGB(160, 230, 255)},
            IceBlock = {mat = Enum.Material.Ice, col = Color3.fromRGB(160, 230, 255)},
            GrassBlock = {mat = Enum.Material.Grass, col = Color3.fromRGB(75, 151, 75)},
            StoneBlock = {mat = Enum.Material.Cobblestone, col = Color3.fromRGB(110, 110, 110)},
            ConcreteBlock = {mat = Enum.Material.Concrete, col = Color3.fromRGB(140, 140, 140)},
        }
        local fb = FB[blockName] or {mat = Enum.Material.Plastic, col = Color3.fromRGB(163, 162, 165)}
        return fb.mat, fb.col
    end

    local function getBI(name)
        local pg = LP:FindFirstChildOfClass("PlayerGui")
        if pg then
            local bf = pg:FindFirstChild("BuildGui")
            if bf then bf = bf:FindFirstChild("InventoryFrame")
            if bf then bf = bf:FindFirstChild("ScrollingFrame")
            if bf then bf = bf:FindFirstChild("BlocksFrame")
            if bf then local tpl = bf:FindFirstChild(name)
            if tpl and tpl:IsA("ImageButton") then return tpl.Image end end end end end
        end
        return ""
    end

    local images = {}
    local thumbButtons = {}
    local imgGrid, imgInfoLabel

    local function loadImages()
        local files = FSys.ls(IMG_DIR)
        images = {}
        for _, f in ipairs(files) do
            if type(f) == "string" then
                local lower = f:lower()
                if lower:match("%.png$") or lower:match("%.jpg$") or lower:match("%.jpeg$") then
                    local name = f:match("([^/\\]+)$") or f
                    images[#images + 1] = {path = f, name = name}
                end
            end
        end
    end

    refreshGrid = function()
        for _, b in ipairs(thumbButtons) do b:Destroy() end
        thumbButtons = {}
        if #images == 0 then
            local empty = mk("TextLabel", imgGrid, {
                Size = UDim2.new(1, 0, 0, 40),
                Text = "No hay imágenes.\nColoca PNG/JPG en:\n" .. IMG_DIR,
                TextColor3 = T.sub, BackgroundTransparency = 1,
                Font = Enum.Font.Gotham, TextSize = 10, TextWrapped = true,
            })
            thumbButtons[1] = empty
            return
        end
        for i, img in ipairs(images) do
            local thumb = mk("TextButton", imgGrid, {
                BackgroundColor3 = T.card, Text = "", LayoutOrder = i, AutoButtonColor = false,
            })
            corner(thumb, 6); stroke(thumb, T.accent, 1)
            local ok, asset = pcall(function() return getcustomasset(img.path) end)
            if ok and asset then
                local imgLabel = mk("ImageLabel", thumb, {
                    Size = UDim2.new(1, -4, 1, -18), Position = UDim2.new(0, 2, 0, 2),
                    BackgroundTransparency = 1, Image = asset, ScaleType = Enum.ScaleType.Fit,
                })
                corner(imgLabel, 4)
            else
                mk("TextLabel", thumb, {
                    Size = UDim2.new(1, -4, 1, -18), Position = UDim2.new(0, 2, 0, 2),
                    Text = "IMG", TextSize = 16, BackgroundTransparency = 1, TextColor3 = T.sub,
                })
            end
            local shortName = img.name
            if #shortName > 12 then shortName = shortName:sub(1, 10) .. ".." end
            mk("TextLabel", thumb, {
                Size = UDim2.new(1, -4, 0, 14), Position = UDim2.new(0, 2, 1, -16),
                Text = shortName, TextColor3 = T.sub, BackgroundTransparency = 1,
                Font = Enum.Font.Gotham, TextSize = 8,
                TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd,
            })
            thumb.MouseButton1Click:Connect(function() selectImage(img) end)
            thumbButtons[#thumbButtons + 1] = thumb
        end
    end

    -- Base64 Encoder para Lua (Necesario para enviar la imagen por HTTP)
    local b64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local function base64Encode(data)
        local t = {}
        local len = #data
        for i = 1, len, 3 do
            local a, b, c, d = data:byte(i), data:byte(i+1) or 0, data:byte(i+2) or 0, 0
            local n = a * 65536 + b * 256 + c
            t[#t+1] = b64Chars:sub(math.floor(n / 262144) % 64 + 1, math.floor(n / 262144) % 64 + 1)
            t[#t+1] = b64Chars:sub(math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1)
            t[#t+1] = (i + 1 <= len) and b64Chars:sub(math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1) or "="
            t[#t+1] = (i + 2 <= len) and b64Chars:sub(n % 64 + 1, n % 64 + 1) or "="
        end
        return table.concat(t)
    end

    selectImage = function(imgInfo)
        if isProcessing then return end
        isProcessing = true
        imgInfoLabel.Text = "Procesando imagen en servidor..."
        imgInfoLabel.TextColor3 = T.warn
        selImage = nil
        hPv()

        local data = FSys.rd(imgInfo.path)
        if not data then 
            imgInfoLabel.Text = "Error: no se pudo leer"; imgInfoLabel.TextColor3 = T.danger
            isProcessing = false; return 
        end

        local res = math.max(1, math.floor(tonumber(resBox.Text) or 32))
        local pSize = math.max(0.1, tonumber(sizeBox.Text) or 1)
        local thick = math.max(0.1, tonumber(thicknessBox.Text) or 2)
        local doMergeVal = doMerge and true or false

        local b64Data = base64Encode(data)
        local payload = HttpService:JSONEncode({
            image = b64Data,
            resolution = res,
            pSize = pSize,
            thickness = thick,
            merge = doMergeVal
        })

        task.spawn(function()
            local success, response = pcall(function()
                local req = (syn and syn.request) or (http and http.request) or (request) or nil
                if not req then error("Tu executor no soporta peticiones HTTP") end
                return req({
                    Url = SERVER_URL,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = payload
                })
            end)

            isProcessing = false

            if not success or not response or response.StatusCode ~= 200 then
                imgInfoLabel.Text = "Error de servidor. ¿Está encendido?"
                imgInfoLabel.TextColor3 = T.danger
                return
            end

            local decoded = HttpService:JSONDecode(response.Body)
            if not decoded or not decoded.success then
                imgInfoLabel.Text = "Error: " .. (decoded and decoded.error or "Desconocido")
                imgInfoLabel.TextColor3 = T.danger
                return
            end

            selImage = {
                name = imgInfo.name,
                blocks = decoded.blocks,
                count = #decoded.blocks
            }
            
            imgInfoLabel.Text = string.format("%s (%d bloques)", imgInfo.name, selImage.count)
            imgInfoLabel.TextColor3 = T.text

            for i, b in ipairs(thumbButtons) do
                if images[i] and images[i].path == imgInfo.path then
                    b.BackgroundColor3 = T.accent
                else
                    b.BackgroundColor3 = T.card
                end
            end
            mPv()
        end)
    end

    do
        local r = bRow(24)
        lbl(r, "GALERÍA DE IMÁGENES", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), T.sub)
        local rBtn = btn(r, "↻", UDim2.new(0, 24, 0, 22), UDim2.new(1, -24, 0, 1), T.btnAlt)
        rBtn.TextSize = 14
        rBtn.MouseButton1Click:Connect(function() loadImages(); refreshGrid() end)
    end

    do
        local r = bRow(180)
        imgGrid = mk("ScrollingFrame", r, {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = T.accent,
            AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0),
        })
        mk("UIGridLayout", imgGrid, {
            CellSize = UDim2.new(0.25, -3, 0, 70), CellPadding = UDim2.new(0, 4, 0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
        pad(imgGrid, 2, 2, 2, 2)
    end

    do
        local r = bRow(20)
        imgInfoLabel = lbl(r, "Ninguna imagen seleccionada", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), T.sub)
        imgInfoLabel.Font = Enum.Font.Gotham; imgInfoLabel.TextSize = 10
        imgInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
    end

    -- (Se omite el selector de material y color por brevedad, es idéntico al anterior)
    local matPickOv, matPickBtn, mLabelRef, mIconRef
    local function updMatBtn(nm, iconId)
        selBlockName = nm
        if mLabelRef then mLabelRef.Text = nm end
        if mIconRef then mIconRef.Image = iconId or DEF_IMG end
        task.spawn(function()
            local mat, col = readRealBlockVisual(nm); sBMat = mat; sBCol = col; mPv()
        end)
    end

    do
        local r = bRow(28)
        local colBtnInd = mk("TextButton", r, {
            Size = UDim2.new(0, 22, 0, 22), Position = UDim2.new(0, 4, 0.5, -11),
            BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Text = "", AutoButtonColor = false,
        })
        corner(colBtnInd, 11); stroke(colBtnInd, T.text, 1.5)

        local bOP = btn(r, "Color", UDim2.new(0, 50, 0, 24), UDim2.new(0, 30, 0.5, -12), T.btn)
        local bTC = btn(r, "OFF", UDim2.new(0, 36, 0, 24), UDim2.new(0, 84, 0.5, -12), T.btnAlt)
        local function refCB()
            bTC.BackgroundColor3 = useColor and WHITE or T.btnAlt
            bTC.TextColor3 = useColor and BLACK or T.text
            bTC.Text = useColor and "ON" or "OFF"
        end
        refCB()
        bTC.MouseButton1Click:Connect(function() useColor = not useColor; refCB(); mPv() end)

        local function openColorPicker()
            openCP(selColor, function(col)
                selColor = col; colBtnInd.BackgroundColor3 = col
                useColor = true; refCB(); mPv()
            end, function(col)
                selColor = col; colBtnInd.BackgroundColor3 = col
                if useColor then mPv() end
            end)
        end
        bOP.MouseButton1Click:Connect(openColorPicker)
        colBtnInd.MouseButton1Click:Connect(openColorPicker)

        matPickBtn = mk("TextButton", r, {
            Size = UDim2.new(1, -130, 0, 24), Position = UDim2.new(0, 126, 0.5, -12),
            BackgroundColor3 = T.input, BorderSizePixel = 0, Font = Enum.Font.GothamSemibold,
            TextSize = 10, Text = "", TextColor3 = T.text, TextXAlignment = Enum.TextXAlignment.Left,
        })
        corner(matPickBtn, 6)
        mIconRef = mk("ImageLabel", matPickBtn, {
            Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(0, 4, 0.5, -10), BackgroundTransparency = 1,
        })
        mLabelRef = mk("TextLabel", matPickBtn, {
            Size = UDim2.new(1, -32, 1, 0), Position = UDim2.new(0, 28, 0, 0), BackgroundTransparency = 1,
            Font = Enum.Font.GothamSemibold, TextSize = 10, TextColor3 = T.text,
            TextXAlignment = Enum.TextXAlignment.Left, Text = selBlockName,
        })

        matPickOv = mk("Frame", ENV.Win, {
            Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0.35, BorderSizePixel = 0, Visible = false, ZIndex = 60,
        })
        mk("TextButton", matPickOv, {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "",
            ZIndex = 60, AutoButtonColor = false,
        }).MouseButton1Click:Connect(function() matPickOv.Visible = false end)

        local pBox = mk("Frame", matPickOv, {
            Size = UDim2.new(1, -20, 0.85, 0), AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundColor3 = T.panel, BorderSizePixel = 0, ZIndex = 61,
        })
        corner(pBox, 10)
        mk("TextLabel", pBox, {
            Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Text = "ELEGIR BLOQUE",
            TextColor3 = T.text, Font = Enum.Font.GothamBold, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 62,
        })
        local pScroll = mk("ScrollingFrame", pBox, {
            Size = UDim2.new(1, -8, 1, -36), Position = UDim2.new(0, 4, 0, 30), BackgroundTransparency = 1,
            BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = T.accent,
            AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 62,
        })
        mk("UIListLayout", pScroll, {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder})
        pad(pScroll, 4, 4, 4, 4)

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
                            Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = T.card, BorderSizePixel = 0,
                            Text = "", LayoutOrder = order, ZIndex = 63,
                        })
                        corner(row, 6)
                        mk("ImageLabel", row, {
                            Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(0, 5, 0.5, -13),
                            BackgroundTransparency = 1, ZIndex = 64, Image = fi ~= "" and fi or DEF_IMG,
                        })
                        mk("TextLabel", row, {
                            Size = UDim2.new(1, -80, 1, 0), Position = UDim2.new(0, 36, 0, 0),
                            BackgroundTransparency = 1, Font = Enum.Font.GothamSemibold, TextSize = 11,
                            TextColor3 = T.text, TextXAlignment = Enum.TextXAlignment.Left, Text = item.Name, ZIndex = 64,
                        })
                        mk("TextLabel", row, {
                            Size = UDim2.new(0, 70, 1, 0), Position = UDim2.new(1, -74, 0, 0),
                            BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 11,
                            TextColor3 = T.sub, TextXAlignment = Enum.TextXAlignment.Right,
                            Text = "x" .. item.Value, ZIndex = 64,
                        })
                        local ci = fi
                        row.MouseButton1Click:Connect(function()
                            updMatBtn(item.Name, ci); matPickOv.Visible = false
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
            if pb and (tonumber(pb.Value) or 0) > 0 then updMatBtn("PlasticBlock", getBI("PlasticBlock"))
            else
                for _, item in ipairs(df:GetChildren()) do
                    if item:IsA("ValueBase") and item.Name:sub(-5) == "Block" and (tonumber(item.Value) or 0) > 0 then
                        updMatBtn(item.Name, getBI(item.Name)); break
                    end
                end
            end
        end)
    end

    local function cleanNum(t)
        local out = {}; local dotUsed = false
        for i = 1, #t do
            local c = t:sub(i, i)
            if c:match("%d") then out[#out + 1] = c
            elseif c == "-" and i == 1 and #out == 0 then out[#out + 1] = c
            elseif c == "." and not dotUsed then out[#out + 1] = c; dotUsed = true end
        end
        return table.concat(out)
    end

    local function bindHold(b, fn)
        local h = false
        local function go()
            if h then return end; h = true; fn()
            task.spawn(function() local d = 0.35; task.wait(d)
                while h do fn(); task.wait(d); d = math.max(0.03, d * 0.75) end end)
        end
        local function stop() h = false end
        b.MouseButton1Down:Connect(go); b.MouseButton1Up:Connect(stop); b.MouseLeave:Connect(stop)
    end

    local function mkNumRow(row, label, default, step, minVal)
        lbl(row, label, UDim2.new(0, 72, 1, 0), UDim2.new(0, 0, 0, 0), T.sub)
        local bl = btn(row, "-", UDim2.new(0, 24, 0, 24), UDim2.new(0, 76, 0, 0), T.btnAlt)
        local bx = box(row, UDim2.new(1, -132, 0, 24), UDim2.new(0, 104, 0, 0), default)
        bx.TextXAlignment = Enum.TextXAlignment.Center
        local br = btn(row, "+", UDim2.new(0, 24, 0, 24), UDim2.new(1, -24, 0, 0), T.btnAlt)
        local decimal = (step < 1) or (minVal and minVal < 1)
        local function fmt(n)
            if minVal then n = math.max(minVal, n) end
            if decimal then
                if n == math.floor(n) then return tostring(math.floor(n))
                else return string.format("%.2f", n) end
            else return tostring(math.floor(n + 0.5)) end
        end
        local guard = false
        bx:GetPropertyChangedSignal("Text"):Connect(function()
            if guard then return end
            local c = cleanNum(bx.Text)
            if c ~= bx.Text then guard = true; bx.Text = c; guard = false end
            mPv()
        end)
        bx.FocusLost:Connect(function()
            local v = tonumber(bx.Text)
            if not v or bx.Text == "" then guard = true; bx.Text = fmt(tonumber(default) or 0); guard = false
            elseif minVal and v < minVal then guard = true; bx.Text = fmt(minVal); guard = false end
            mPv()
        end)
        bindHold(bl, function() local cur = tonumber(bx.Text) or (minVal or 0)
            local nv = cur - step; if minVal then nv = math.max(minVal, nv) end
            guard = true; bx.Text = fmt(nv); guard = false; mPv() end)
        bindHold(br, function() local cur = tonumber(bx.Text) or (minVal or 0)
            local nv = cur + step; if minVal then nv = math.max(minVal, nv) end
            guard = true; bx.Text = fmt(nv); guard = false; mPv() end)
        return bx
    end

    local resBox, sizeBox, thicknessBox, mergeBtn
    local doMerge = false
    do local r = bRow(24); resBox = mkNumRow(r, "Resolución", "32", 1, 1) end
    do local r = bRow(24); sizeBox = mkNumRow(r, "Tam. Pixel", "1", 0.1, 0.1) end
    do local r = bRow(24); thicknessBox = mkNumRow(r, "Grosor", "2", 0.1, 0.1) end

    do
        local r = bRow(24)
        lbl(r, "Unir colores", UDim2.new(0, 100, 1, 0), UDim2.new(0, 0, 0, 0), T.sub)
        mergeBtn = btn(r, "OFF", UDim2.new(0, 50, 0, 22), UDim2.new(1, -54, 0, 1), T.btnAlt)
        local function refM()
            mergeBtn.BackgroundColor3 = doMerge and WHITE or T.btnAlt
            mergeBtn.TextColor3 = doMerge and BLACK or T.text
            mergeBtn.Text = doMerge and "ON" or "OFF"
        end
        refM()
        mergeBtn.MouseButton1Click:Connect(function() doMerge = not doMerge; refM(); mPv() end)
    end

    local BtnBldC, BtnBldS; local bCZ = true
    local function rfBP()
        BtnBldC.BackgroundColor3 = bCZ and WHITE or T.btnAlt
        BtnBldC.TextColor3 = bCZ and BLACK or T.text
        BtnBldS.BackgroundColor3 = (not bCZ) and WHITE or T.btnAlt
        BtnBldS.TextColor3 = (not bCZ) and BLACK or T.text
    end

    local function getZoneSurface(z)
        if z and z:IsA("BasePart") then return z.Position + Vector3.new(0, z.Size.Y / 2 + 0.5, 0) end
        return Vector3.zero
    end

    local yOffset = 3
    local function centerOnCZ()
        local z = closestZone(myRefPos())
        if z then
            baseCPos = getZoneSurface(z)
            cP = baseCPos + Vector3.new(0, yOffset, 0)
            sR = CFrame.identity; hR = false
            cDummy.CFrame = CFrame.new(cP)
            ArcAdornee.CFrame = CFrame.new(cP)
            updateHandles(); mPv(); return true
        end
        return false
    end

    do
        local r = bRow(28)
        BtnBldC = btn(r, "Centro zona", UDim2.new(0.5, -3, 1, 0), UDim2.new(0, 0, 0, 0), WHITE)
        BtnBldC.TextColor3 = BLACK
        BtnBldS = btn(r, "Sel. Posición", UDim2.new(0.5, -3, 1, 0), UDim2.new(0.5, 3, 0, 0), T.btnAlt)
        BtnBldC.MouseButton1Click:Connect(function() bCZ = true; rfBP(); centerOnCZ() end)
        local bSel2 = false
        BtnBldS.MouseButton1Click:Connect(function()
            if bSel2 or lk then return end; bSel2 = true; bCZ = false; rfBP()
            BtnBldS.Text = "Haz clic..."
            local rc, cc
            rc = RunService.RenderStepped:Connect(function() selBox.Adornee = Mouse.Target end)
            cc = Mouse.Button1Down:Connect(function()
                local t = Mouse.Target
                if t and t:IsA("BasePart") and not t:IsDescendantOf(SG) then
                    baseCPos = t.Position
                    cP = baseCPos + Vector3.new(0, yOffset, 0)
                    sR = CFrame.identity; hR = false
                    cDummy.CFrame = CFrame.new(cP)
                    ArcAdornee.CFrame = CFrame.new(cP)
                    rc:Disconnect(); cc:Disconnect(); selBox.Adornee = nil; bSel2 = false
                    BtnBldS.Text = "Sel. Posición"; updateHandles(); mPv()
                end
            end)
        end)
    end
    rfBP()

    local bMove, bRotT, moveStepBox, rotStepBox
    local function rfT()
        bMove.BackgroundColor3 = (tM == "move") and T.btn or T.btnAlt
        bRotT.BackgroundColor3 = (tM == "rotate") and T.btn or T.btnAlt
        updateHandles()
    end

    local function stepVal(bx) local v = tonumber(bx and bx.Text); if not v or v < 0 then v = 0 end; return v end

    local function mkStepBox(parent, size, pos, default)
        local bx = box(parent, size, pos, default); bx.TextXAlignment = Enum.TextXAlignment.Center
        local guard = false
        bx:GetPropertyChangedSignal("Text"):Connect(function()
            if guard then return end; local c = cleanNum(bx.Text)
            if c ~= bx.Text then guard = true; bx.Text = c; guard = false end end)
        bx.FocusLost:Connect(function()
            local v = tonumber(bx.Text)
            if not v or v < 0 then guard = true; bx.Text = "0"; guard = false end end)
        return bx
    end

    do
        local r = bRow(26)
        bMove = btn(r, "", UDim2.new(0, 44, 0, 26), UDim2.new(0, 0, 0, 0), T.btn)
        mk("ImageLabel", bMove, {Size = UDim2.new(0, 18, 0, 18), Position = UDim2.new(0.5, -9, 0.5, -9), BackgroundTransparency = 1, Image = ICON_MOVE})
        moveStepBox = mkStepBox(r, UDim2.new(0.5, -51, 0, 26), UDim2.new(0, 48, 0, 0), "1")
        bRotT = btn(r, "", UDim2.new(0, 44, 0, 26), UDim2.new(0.5, 3, 0, 0), T.btnAlt)
        mk("ImageLabel", bRotT, {Size = UDim2.new(0, 18, 0, 18), Position = UDim2.new(0.5, -9, 0.5, -9), BackgroundTransparency = 1, Image = ICON_ROT})
        rotStepBox = mkStepBox(r, UDim2.new(0.5, -51, 0, 26), UDim2.new(0.5, 51, 0, 0), "15")
        bMove.MouseButton1Click:Connect(function() tM = "move"; rfT() end)
        bRotT.MouseButton1Click:Connect(function() tM = "rotate"; rfT() end)
    end

    do
        local drag2, savedCam, origDP, origBaseCPos = false, nil, nil, nil
        Handles.MouseButton1Down:Connect(function()
            if not PB.Visible or lk or not cP then return end
            drag2 = true; origDP = cDummy.Position; origBaseCPos = baseCPos
            savedCam = Camera.CFrame; Camera.CameraType = Enum.CameraType.Scriptable
        end)
        Handles.MouseDrag:Connect(function(face, dist)
            if not PB.Visible or not drag2 or not origDP then return end
            local st = stepVal(moveStepBox)
            local d = (st > 0) and (math.floor(dist / st + 0.5) * st) or dist
            local moveVec = cDummy.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face)) * d
            cP = origDP + moveVec
            if origBaseCPos then baseCPos = origBaseCPos + moveVec end
            cDummy.Position = cP; mPv()
        end)
        Handles.MouseButton1Up:Connect(function()
            if not PB.Visible then return end; drag2 = false; savedCam = nil
            Camera.CameraType = Enum.CameraType.Custom
        end)

        local arcDrag, arcStartRot, arcSavedCam = false, nil, nil
        Arc.MouseButton1Down:Connect(function()
            if lk or not cP then return end; arcDrag = true; arcStartRot = sR
            arcSavedCam = Camera.CFrame; Camera.CameraType = Enum.CameraType.Scriptable
        end)
        Arc.MouseDrag:Connect(function(axis, relAngle)
            if not arcDrag then return end
            local av = (axis == Enum.Axis.X and Vector3.xAxis) or (axis == Enum.Axis.Y and Vector3.yAxis) or Vector3.zAxis
            local st = stepVal(rotStepBox)
            local snapped = (st > 0) and math.rad(math.floor(math.deg(relAngle) / st + 0.5) * st) or relAngle
            sR = arcStartRot * CFrame.fromAxisAngle(av, snapped); hR = true
            if cP then cDummy.CFrame = CFrame.new(cP) * sR end; mPv()
        end)
        Arc.MouseButton1Up:Connect(function()
            arcDrag = false; arcSavedCam = nil; Camera.CameraType = Enum.CameraType.Custom
        end)

        RunService.RenderStepped:Connect(function()
            if drag2 and savedCam then Camera.CFrame = savedCam end
            if arcDrag and arcSavedCam then Camera.CFrame = arcSavedCam end
            if cP and hR then cDummy.CFrame = CFrame.new(cP) * sR
            elseif cP then cDummy.Position = cP end
            if cP then ArcAdornee.CFrame = CFrame.new(cP) * sR
            else ArcAdornee.Position = Vector3.new(0, -9999, 0) end
            if PB.Visible and cP and not lk then
                if tM == "move" then
                    if Handles.Adornee ~= cDummy then Handles.Adornee = cDummy end
                    if not Handles.Visible then Handles.Visible = true end
                    if Arc.Visible then Arc.Visible = false end
                elseif tM == "rotate" then
                    if Arc.Adornee ~= ArcAdornee then Arc.Adornee = ArcAdornee end
                    if not Arc.Visible then Arc.Visible = true end
                    if Handles.Visible then Handles.Visible = false end
                end
            elseif not PB.Visible then
                if Handles.Visible then Handles.Visible = false end
                if Arc.Visible then Arc.Visible = false end
            end
        end)
    end

    local pp = {}
    hPv = function()
        for _, p in ipairs(pp) do p.Transparency = 1; p.Size = Vector3.new(0.05, 0.05, 0.05) end
    end

    local pD = false
    mPv = function() pD = true end

    local function generatePlan()
        if not selImage or not cP then return {} end
        -- El servidor ya hizo todo el trabajo, solo aplicamos la rotación y posición de Roblox
        local plan = {}
        local cx, cy, cz = cP.X, cP.Y, cP.Z
        local centerCF = CFrame.new(cx, cy, cz)

        for _, blk in ipairs(selImage.blocks) do
            local localCF = CFrame.new(blk.x, blk.y, blk.z)
            local finalCF = hR and (centerCF * sR * (centerCF:Inverse() * localCF)) or localCF
            plan[#plan + 1] = {
                cframe = finalCF + Vector3.new(cx, cy, cz),
                size = Vector3.new(blk.sx, blk.sy, blk.sz),
                color = Color3.new(blk.r, blk.g, blk.b),
            }
        end
        return plan
    end

    local function rnP(plan)
        local maxP = 2500; local stride = 1
        if #plan > maxP then stride = math.ceil(#plan / maxP) end
        local n = 0
        for i = 1, #plan, stride do
            n = n + 1; local p = pp[n]
            if not p then
                p = mk("Part", prevF, {Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false})
                pp[n] = p
            end
            p.Size = plan[i].size; p.CFrame = plan[i].cframe
            p.Material = sBMat
            p.Color = useColor and selColor or (plan[i].color or sBCol)
            p.Transparency = pA
        end
        for i = n + 1, #pp do pp[i].Transparency = 1; pp[i].Size = Vector3.new(0.05, 0.05, 0.05) end
        return #plan, (stride > 1)
    end

    local function dPv()
        if not PB.Visible then hPv(); return end
        if not cP or not pOn or lk or not selImage then hPv(); return end
        local plan = generatePlan()
        if not plan or #plan == 0 then hPv(); return end
        local minv = Vector3.new(math.huge, math.huge, math.huge)
        local maxv = Vector3.new(-math.huge, -math.huge, -math.huge)
        for _, seg in ipairs(plan) do
            local hS = seg.size / 2; local p = seg.cframe.Position
            minv = Vector3.new(math.min(minv.X, p.X - hS.X), math.min(minv.Y, p.Y - hS.Y), math.min(minv.Z, p.Z - hS.Z))
            maxv = Vector3.new(math.max(maxv.X, p.X + hS.X), math.max(maxv.Y, p.Y + hS.Y), math.max(maxv.Z, p.Z + hS.Z))
        end
        if minv.X ~= math.huge then
            local size = maxv - minv
            cDummy.Size = Vector3.new(math.clamp(size.X, 4, 200), math.clamp(size.Y, 4, 200), math.clamp(size.Z, 4, 200))
        else cDummy.Size = Vector3.new(4, 4, 4) end
        ArcAdornee.Size = cDummy.Size
        local total, sampled = rnP(plan)
        if sampled then setStat(("preview %d bloques (muestra)"):format(total), T.warn)
        else setStat(("preview %d bloques"):format(total), T.sub) end
    end

    RunService.Heartbeat:Connect(function() if pD then pD = false; dPv() end end)

    local BPr, BB, SL
    setStat = function(t, col) if SL then SL.Text = t; SL.TextColor3 = col or T.text end end

    do
        local r = bRow(32)
        BPr = btn(r, "Vista previa: On", UDim2.new(1, -80, 1, 0), nil, WHITE); BPr.TextColor3 = BLACK
        local prevAlphaFrame = mk("Frame", r, {Size = UDim2.new(0, 76, 1, 0), Position = UDim2.new(1, -76, 0, 0), BackgroundColor3 = T.btnAlt, BorderSizePixel = 0})
        corner(prevAlphaFrame, 6)
        local pAlphaDown = btn(prevAlphaFrame, "-", UDim2.new(0, 22, 1, 0), UDim2.new(0, 0, 0, 0), T.btnAlt)
        local pAlphaLbl = lbl(prevAlphaFrame, math.floor(pA * 100) .. "%", UDim2.new(0, 28, 1, 0), UDim2.new(0, 22, 0, 0), T.text)
        pAlphaLbl.TextXAlignment = Enum.TextXAlignment.Center; pAlphaLbl.Font = Enum.Font.GothamBold; pAlphaLbl.TextSize = 10
        local pAlphaUp = btn(prevAlphaFrame, "+", UDim2.new(0, 22, 1, 0), UDim2.new(1, -22, 0, 0), T.btnAlt)
        local function setAlpha(v) pA = math.clamp(v, 0, 0.95); pAlphaLbl.Text = math.floor(pA * 100) .. "%"; mPv() end
        pAlphaDown.MouseButton1Click:Connect(function() setAlpha(pA - 0.10) end)
        pAlphaUp.MouseButton1Click:Connect(function() setAlpha(pA + 0.10) end)
        BPr.MouseButton1Click:Connect(function()
            if lk then return end; pOn = not pOn
            BPr.Text = pOn and "Vista previa: On" or "Vista previa: Off"
            BPr.BackgroundColor3 = pOn and WHITE or T.btnAlt
            BPr.TextColor3 = pOn and BLACK or T.text; mPv()
        end)
    end

    do
        local r = bRow(32)
        BB = btn(r, "Construir", UDim2.new(1, 0, 1, 0), nil, WHITE); BB.TextColor3 = BLACK
        SL = mk("TextLabel", BB, {Size = UDim2.new(0, 100, 0, 12), Position = UDim2.new(1, -104, 1, -16), Text = "listo", TextColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Right})
    end

    local blockQueue = {}; local blockConn = nil
    local function hookFolder(folder)
        if blockConn then blockConn:Disconnect(); blockConn = nil end
        blockQueue = {}
        if folder then blockConn = folder.ChildAdded:Connect(function(c) blockQueue[#blockQueue + 1] = c end) end
    end
    local function popBlock(timeout)
        local t0 = tick()
        while #blockQueue == 0 do
            if bS.cancel then return nil end
            if tick() - t0 > timeout then return nil end
            task.wait()
        end
        return table.remove(blockQueue, 1)
    end

    local function setLocked(s)
        lk = s; for _, b in ipairs(thumbButtons) do b.Active = not s end; updateHandles()
    end

    local function iniciarConstruccion()
        if gbRunRef.value then setStat("ya hay construcción en curso", T.danger); return end
        if not cP then setStat("selecciona un centro primero", T.danger); return end
        if not selImage then setStat("selecciona una imagen primero", T.danger); return end
        local sharing = isSharing(); local activeData = getActiveData()
        local invItem = activeData and activeData:FindFirstChild(selBlockName)
        if not invItem or invItem.Value <= 0 then setStat("material no válido / sin stock", T.danger); return end
        local bTool = getActiveTool("BuildingTool")
        if not bTool then setStat("falta BuildingTool", T.danger); return end
        local sTool = getActiveTool("ScalingTool")
        local pTool = getActiveTool("PaintingTool")

        bS.running = true; bS.cancel = false; gbRunRef.value = true
        BB.Text = "Cancelar"; BB.BackgroundColor3 = T.danger; BB.TextColor3 = BLACK
        setLocked(true); hPv()

        local ok2, err = pcall(function()
            local plan = generatePlan(); local total = #plan
            if total == 0 then error("plan vacío") end
            if not sharing then equipTool(bTool); equipTool(sTool); if useColor and pTool then equipTool(pTool) end end
            local bRF = bTool and bTool:FindFirstChild("RF")
            local sRF = sTool and sTool:FindFirstChild("RF")
            local pRF = pTool and pTool:FindFirstChild("RF")
            if not bRF then error("BuildingTool sin RF") end
            local folder = userFolder(LP.Name); hookFolder(folder)
            local placed = 0; local pBl = {}

            local function placeOne(seg)
                local ret = bRF:InvokeServer(selBlockName, invItem.Value, nil, seg.cframe, true, seg.cframe, false)
                local blk
                if typeof(ret) == "Instance" and ret:IsA("BasePart") then blk = ret else blk = popBlock(3) end
                if blk and sRF then pcall(function() sRF:InvokeServer(blk, seg.size, seg.cframe) end) end
                return blk
            end

            local WORKERS = sharing and 15 or 50; local nextIdx = 1; local active = WORKERS
            local function worker()
                while true do
                    if bS.cancel then break end
                    if invItem.Value <= 0 then break end
                    local i = nextIdx; nextIdx = nextIdx + 1; if i > total then break end
                    if not folder or folder.Parent == nil then folder = userFolder(LP.Name); hookFolder(folder) end
                    
                    local blk = placeOne(plan[i])
                    if blk then 
                        placed = placed + 1
                        pBl[#pBl + 1] = {block = blk, color = useColor and selColor or plan[i].color}
                    end
                end
                active = active - 1
            end
            for _ = 1, WORKERS do task.spawn(worker) end
            while active > 0 do setStat(("Construyendo %d/%d"):format(placed, total), T.warn); task.wait(0.03) end
            if blockConn then blockConn:Disconnect(); blockConn = nil end

            if not bS.cancel and #pBl > 0 then
                setStat(("Pintando %d bloques..."):format(#pBl), T.warn)
                local paintData = {}
                for _, item in ipairs(pBl) do
                    paintData[#paintData + 1] = {item.block, item.color}
                end
                if pRF then paintBatch(pRF, paintData) end
            end

            if bS.cancel then setStat(("Cancelado (%d colocados)"):format(placed), T.danger)
            else setStat(("listo - %d/%d bloques"):format(placed, total), T.ok) end
        end)

        if blockConn then blockConn:Disconnect(); blockConn = nil end
        if not ok2 then setStat("error: " .. tostring(err), T.danger) end
        local hum = LP.Character and LP.Character:FindFirstChild("Humanoid")
        if hum then pcall(function() hum:UnequipTools() end) end
        bS.running = false; bS.cancel = false; gbRunRef.value = false
        BB.Text = "Construir"; BB.BackgroundColor3 = WHITE; BB.TextColor3 = BLACK
        setLocked(false); if pOn then mPv() end
    end

    BB.MouseButton1Click:Connect(function()
        if bS.running then bS.cancel = true; setStat("cancelando...", T.danger); return end
        task.spawn(iniciarConstruccion)
    end)

    local function waitAndRecenter()
        task.spawn(function()
            for _ = 1, 20 do
                task.wait(0.3)
                local ok, ref = pcall(myRefPos)
                if ok and ref and ref.Y > -100 then
                    if centerOnCZ() then bCZ = true; rfBP(); needsRecenter = false; return end
                end
            end
            needsRecenter = true
        end)
    end

    LP:GetPropertyChangedSignal("Team"):Connect(function()
        if PB.Visible then waitAndRecenter() else needsRecenter = true end
    end)
    LP.CharacterAdded:Connect(function(char)
        local hrp = char:WaitForChild("HumanoidRootPart", 8); if not hrp then return end
        task.wait(0.2)
        if PB.Visible then waitAndRecenter() else needsRecenter = true end
    end)
    PB:GetPropertyChangedSignal("Visible"):Connect(function()
        if PB.Visible and needsRecenter then needsRecenter = false; waitAndRecenter() end
    end)

    rfT(); rfBP(); loadImages(); refreshGrid()
    task.defer(function() task.wait(0.3); rfT() end)
    task.spawn(function() task.wait(1); if centerOnCZ() then bCZ = true; rfBP() end end)

    return {
        page = PB, hidePreview = hPv, markPreview = mPv,
        handles = Handles, arc = Arc, arcAdornee = ArcAdornee, cDummy = cDummy,
    }
end

return ImagenesModule
