-- main.lua
-- Kimiko Hub - Build a Boat For Treasure
-- Carga módulos desde GitHub: formas.lua y builds.lua

-- ===================================================================
-- CONFIGURACIÓN DE GITHUB (cambia usuario/repo si es necesario)
-- ===================================================================
local GITHUB_RAW   = "https://raw.githubusercontent.com/TU_USUARIO/TU_REPO/main/"
local MOD_FORMAS   = GITHUB_RAW .. "formas.lua"
local MOD_BUILDS   = GITHUB_RAW .. "builds.lua"

-- ===================================================================
-- SERVICIOS
-- ===================================================================
local CoreGui          = game:GetService("CoreGui")
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local Teams            = game:GetService("Teams")

local LP     = Players.LocalPlayer
local Mouse  = LP:GetMouse()
local Camera = workspace.CurrentCamera

-- ===================================================================
-- FUNCIÓN PARA CARGAR MÓDULO DESDE GITHUB
-- ===================================================================
local function loadModule(url)
    local ok, result = pcall(function()
        -- Intentar con syn.request, http.request, request
        local body
        if syn and syn.request then
            local r = syn.request({Url=url, Method="GET"})
            body = r.Body
        elseif http and http.request then
            local r = http.request({Url=url, Method="GET"})
            body = r.Body
        elseif request then
            local r = request({Url=url, Method="GET"})
            body = r.Body
        elseif game:GetService("HttpService").GetAsync then
            body = game:GetService("HttpService"):GetAsync(url)
        end
        if not body then error("Sin respuesta de "..url) end
        local fn = loadstring(body)
        if not fn then error("loadstring falló para "..url) end
        return fn()
    end)
    if not ok then
        warn("[KimikoHub] Error cargando módulo "..url..": "..tostring(result))
        return nil
    end
    return result
end

-- ===================================================================
-- GUI RAÍZ
-- ===================================================================
local GP do
    local ok,g = pcall(function() return gethui() end)
    GP = (ok and g) and g or CoreGui
end
if GP:FindFirstChild("KIMIKO_SB")  then GP.KIMIKO_SB:Destroy()  end
if workspace:FindFirstChild("KIMIKO_ENV") then workspace.KIMIKO_ENV:Destroy() end

-- ===================================================================
-- TEMA
-- ===================================================================
local T = {
    bg      = Color3.fromRGB(0,0,0),           -- negro puro
    panel   = Color3.fromRGB(0,0,0),           -- negro puro
    card    = Color3.fromRGB(22,22,22),
    input   = Color3.fromRGB(32,32,32),
    accent  = Color3.fromRGB(180,180,180),
    btn     = Color3.fromRGB(55,55,55),
    btnAlt  = Color3.fromRGB(38,38,38),
    text    = Color3.fromRGB(235,235,235),
    sub     = Color3.fromRGB(140,140,140),
    build   = Color3.fromRGB(75,145,90),
    danger  = Color3.fromRGB(180,65,65),
    ok      = Color3.fromRGB(75,155,100),
    warn    = Color3.fromRGB(195,145,45),
    purple  = Color3.fromRGB(170,0,255),   -- morado gamer saturado
}

-- ===================================================================
-- ZONAS
-- ===================================================================
local ZONES = {"Really redZone","Really blueZone","MagentaZone","CamoZone","BlackZone","WhiteZone","New YellerZone"}
local ZONE_DATA = {
    ["WhiteZone"]     = {pos=Vector3.new(-53.566,-18,-345.507),  rotY=0,   size=Vector3.new(251.8,10.2,299)},
    ["Really redZone"]= {pos=Vector3.new(221.834,-18,-68.707),   rotY=-90, size=Vector3.new(251.8,10.2,299)},
    ["Really blueZone"]={pos=Vector3.new(221.834,-18,289.493),   rotY=-90, size=Vector3.new(251.8,10.2,299)},
    ["New YellerZone"]= {pos=Vector3.new(-328.966,-18,643.893),  rotY=90,  size=Vector3.new(251.8,10.2,299)},
    ["MagentaZone"]   = {pos=Vector3.new(221.834,-18,647.693),   rotY=-90, size=Vector3.new(251.8,10.2,299)},
    ["CamoZone"]      = {pos=Vector3.new(-328.966,-18,285.893),  rotY=90,  size=Vector3.new(251.8,10.2,299)},
    ["BlackZone"]     = {pos=Vector3.new(-328.966,-18,-72.107),  rotY=90,  size=Vector3.new(251.8,10.2,299)},
}

local ICON_LEADER = "rbxassetid://1912631373"
local ICON_MOVE   = "rbxassetid://10959947484"
local ICON_ROT    = "rbxassetid://10959947716"

local function getZoneOrientCF(zn)
    local z = workspace:FindFirstChild(zn)
    if z and z:IsA("BasePart") then return z.CFrame end
    local d = ZONE_DATA[zn]; if d then return CFrame.new(d.pos)*CFrame.Angles(0,math.rad(d.rotY),0) end
end
local function getZoneCFForPos(refPos)
    local best,bestD=nil,math.huge
    for _,zn in ipairs(ZONES) do
        local z=workspace:FindFirstChild(zn)
        if z and z:IsA("BasePart") then local d=(z.Position-refPos).Magnitude; if d<bestD then best,bestD=z.Name,d end
        else local zd=ZONE_DATA[zn]; if zd then local d=(zd.pos-refPos).Magnitude; if d<bestD then best,bestD=zn,d end end end
    end
    return best and getZoneOrientCF(best), best
end
local function zoneDeltaRot(src,dst)
    if not src or not dst or src==dst then return CFrame.identity end
    local sC=getZoneOrientCF(src); local dC=getZoneOrientCF(dst)
    if not sC or not dC then return CFrame.identity end
    return (sC-sC.Position):Inverse()*(dC-dC.Position)
end

-- ===================================================================
-- FILE SYSTEM
-- ===================================================================
local FR  = "Kimiko_Hub"
local FG  = FR.."/Build a Boat For Treasure"
local FS2 = FG.."/Builds"
local function cS(n,...) local fn=getfenv()[n] or _G[n]; if type(fn)=="function" then return pcall(fn,...) end; return false end
local FSys = {}
FSys.isf = function(p) local ok,r=cS("isfolder",p); return ok and r end
FSys.mkf = function(p) if FSys.isf(p) then return end; cS("makefolder",p); cS("createfolder",p); task.wait(0.05) end
FSys.wr  = function(p,c) local ok,e=cS("writefile",p,c); if ok then return true end; warn("[K]wr fail "..tostring(e)); return false end
FSys.rd  = function(p) local ok,d=cS("readfile",p); if ok and type(d)=="string" then return d end end
FSys.ls  = function(p) local ok,f=cS("listfiles",p); if ok and type(f)=="table" then return f end; return{} end
FSys.del = function(p) cS("delfile",p); cS("removefile",p) end
local fReady=false
local function ensF() FSys.mkf(FR); FSys.mkf(FG); FSys.mkf(FS2); fReady=true end
local function readBF(path) local r=FSys.rd(path); if not r or r=="" then return nil end; local ok,t=pcall(function() return HttpService:JSONDecode(r) end); if ok and type(t)=="table" then return t end end
local function writeBF(nm,data) if not fReady then ensF() end; local p=FS2.."/"..nm..".json"; local ok,enc=pcall(function() return HttpService:JSONEncode(data) end); if ok and enc then if FSys.wr(p,enc) then return p end end end
ensF()

local OP  = FG.."/_order.json"
local ORD = {}
local function sOrd() FSys.wr(OP, HttpService:JSONEncode(ORD)) end
local function lOrd() local r=FSys.rd(OP); if r then local ok,t=pcall(function() return HttpService:JSONDecode(r) end); if ok and type(t)=="table" then ORD=t end end end
lOrd()
local function syncOrd()
    local f=FSys.ls(FS2); local fn={}
    for _,p in ipairs(f) do if type(p)=="string" and p:lower():match("%.json$") and not p:match("_order%.json$") then fn[#fn+1]=p:match("([^/\\]+)%.json$") end end
    local nO={}; local sn={}
    for _,nm in ipairs(ORD) do if table.find(fn,nm) then nO[#nO+1]=nm; sn[nm]=true end end
    for _,nm in ipairs(fn) do if not sn[nm] then table.insert(nO,1,nm); sn[nm]=true end end
    ORD=nO; sOrd()
end
local function addSaveOrd(nm) table.insert(ORD,1,nm); sOrd() end
local function delSaveOrd(nm) local i=table.find(ORD,nm); if i then table.remove(ORD,i); sOrd() end end

local GKEY = "KIMIKO_SB_SAVES"
local Saves = {}
local readSaves,writeSaves,autoName,reloadSaves
do
    readSaves = function()
        syncOrd(); local L={}
        for _,nm in ipairs(ORD) do local p=FS2.."/"..nm..".json"; local d=readBF(p); if d and d.name and d.data then L[#L+1]={name=d.name,data=d.data,_path=p} end end
        _G[GKEY]=L; return L
    end
    writeSaves = function(tbl)
        _G[GKEY]=tbl; if not fReady then ensF() end
        for _,sv in ipairs(tbl) do if sv.name and sv.data then local p=sv._path or(FS2.."/"..sv.name..".json"); local ok,enc=pcall(function() return HttpService:JSONEncode({name=sv.name,data=sv.data}) end); if ok and enc then FSys.wr(p,enc) end end end
    end
    reloadSaves = function() local n=readSaves(); for i,v in ipairs(n) do Saves[i]=v end; while Saves[#Saves+1] do table.remove(Saves) end; return n end
    autoName = function() local used={}; for _,s in ipairs(Saves) do used[s.name]=true end; local n=1; while used["Build"..n] do n=n+1 end; return "Build"..n end
end
Saves = readSaves()

-- ===================================================================
-- PLAYER HELPERS
-- ===================================================================
local dataFolder = LP:FindFirstChild("Data") or LP:WaitForChild("Data",5)

local getTool,equipTool,blocksRoot,userFolder,myRefPos,closestZone,getPPart,captureBuild
do
    getTool    = function(nm) local ch,bp=LP.Character,LP:FindFirstChild("Backpack"); return (ch and ch:FindFirstChild(nm)) or (bp and bp:FindFirstChild(nm)) end
    equipTool  = function(tool) local ch=LP.Character; if ch and tool and tool.Parent~=ch then tool.Parent=ch; task.wait(0.08) end end
    blocksRoot = function() return workspace:FindFirstChild("Blocks") end
    userFolder = function(nm) local r=blocksRoot(); return r and r:FindFirstChild(nm or LP.Name) end
    myRefPos   = function() local ch=LP.Character; if ch and ch:FindFirstChild("HumanoidRootPart") then return ch.HumanoidRootPart.Position end; local uf=userFolder(LP.Name); if uf then for _,d in ipairs(uf:GetDescendants()) do if d:IsA("BasePart") then return d.Position end end end; return Vector3.zero end
    closestZone = function(refPos) local best,bestD=nil,math.huge; for _,zn in ipairs(ZONES) do local z=workspace:FindFirstChild(zn); if z and z:IsA("BasePart") then local d=(z.Position-refPos).Magnitude; if d<bestD then best,bestD=z,d end end end; return best,bestD end
    getPPart   = function(inst) if inst:FindFirstChild("PPart") and inst.PPart:IsA("BasePart") then return inst.PPart end; if inst:IsA("BasePart") then return inst end; return inst:FindFirstChildWhichIsA("BasePart",true) end
    captureBuild = function(pName,fallCF)
        local uf=userFolder(pName); if not uf then return nil,"sin bloques" end
        local refPos=nil; for _,d in ipairs(uf:GetDescendants()) do if d:IsA("BasePart") then refPos=d.Position; break end end
        local sZN,sZCF; if refPos then sZCF,sZN=getZoneCFForPos(refPos) end
        if not sZCF then sZCF=fallCF or CFrame.new(refPos or Vector3.zero) end
        if not sZN  then sZN="Unknown" end
        local data={Block={},SrcZoneName=sZN}; local count=0
        for _,child in ipairs(uf:GetDescendants()) do
            if (child:IsA("Model") or child:IsA("Folder") or child:IsA("BasePart")) and child.Name:sub(-5)=="Block" then
                local part=getPPart(child); if part and part:IsA("BasePart") then
                    local rel=sZCF:Inverse()*part.CFrame; local rx,ry,rz=rel:ToEulerAnglesXYZ()
                    table.insert(data.Block,{BlockName=child.Name,RelX=rel.X,RelY=rel.Y,RelZ=rel.Z,RotX=math.deg(rx),RotY=math.deg(ry),RotZ=math.deg(rz),SizeX=part.Size.X,SizeY=part.Size.Y,SizeZ=part.Size.Z,ColorR=part.Color.R,ColorG=part.Color.G,ColorB=part.Color.B,Material=part.Material.Name})
                    count=count+1
                end
            end
        end
        if count==0 then return nil,"0 bloques" end
        return data,count
    end
end

local function countPB(pName)
    local uf=userFolder(pName); if not uf then return 0 end; local c=0
    for _,child in ipairs(uf:GetDescendants()) do if (child:IsA("Model") or child:IsA("Folder") or child:IsA("BasePart")) and child.Name:sub(-5)=="Block" then local part=getPPart(child); if part and part:IsA("BasePart") then c=c+1 end end end
    return c
end

local function getTeamColor(uname)
    for _,p in ipairs(Players:GetPlayers()) do if p.Name==uname then if p.Team and p.Team.TeamColor then local tc=p.Team.TeamColor.Color; return Color3.new(math.clamp(tc.R*0.35,0,1),math.clamp(tc.G*0.35,0,1),math.clamp(tc.B*0.35,0,1)) end; break end end
    return T.input
end
local function isLdr(un)
    local pg=LP:FindFirstChildOfClass("PlayerGui"); if not pg then return false end
    local sf=pg:FindFirstChild("PlayerListGui"); if sf then sf=sf:FindFirstChild("Frame"); if sf then sf=sf:FindFirstChild("ScrollingFrame") end end
    if not sf then return false end
    for _,c in ipairs(sf:GetChildren()) do if c.Name=="PlayerLabel" then local pn=c:FindFirstChild("PlayerName"); local pr=c:FindFirstChild("PlayerRank"); if pn and pn:IsA("TextLabel") and pr and pr:IsA("ImageLabel") and pn.Text==un then return pr.Visible end end end
    return false
end
local function isSharing()
    local s=LP:FindFirstChild("Settings"); if s then local sb=s:FindFirstChild("ShareBlocks"); if sb then return sb.Value==true end end; return false
end
local function getMyLeader()
    local myT=LP.Team; if not myT then return nil end
    for _,p in ipairs(Players:GetPlayers()) do if p.Team==myT and isLdr(p.Name) then return p.Name end end
    return nil
end
local function getShareSource()
    if not isSharing() then return nil,nil end
    local leaderName=getMyLeader(); if not leaderName or leaderName==LP.Name then return nil,nil end
    local leaderPlayer=Players:FindFirstChild(leaderName); if not leaderPlayer then return nil,nil end
    return leaderPlayer:FindFirstChild("Data"),leaderPlayer:FindFirstChild("Backpack"),leaderName
end
local function getActiveData() local lData,lBP,lName=getShareSource(); if lData then return lData,lName end; return dataFolder,LP.Name end
local function getActiveTool(toolName)
    if isSharing() then local _,lBP,lName=getShareSource(); if lBP then local t=lBP:FindFirstChild(toolName); if t then return t end; local lChar=Players:FindFirstChild(lName or ""); lChar=lChar and lChar.Character; if lChar then t=lChar:FindFirstChild(toolName); if t then return t end end end end
    return getTool(toolName)
end
local function paintBatch(pRF, paintData)
    if not pRF or #paintData==0 then return end
    local BATCH=500
    for i=1,#paintData,BATCH do
        local chunk={}; for j=i,math.min(i+BATCH-1,#paintData) do chunk[#chunk+1]=paintData[j] end
        pcall(function() pRF:InvokeServer(chunk) end)
        if #paintData>BATCH then task.wait(0.05) end
    end
end

-- ===================================================================
-- UI HELPERS
-- ===================================================================
local mk, corner, stroke, pad, lbl, box, btn
do
    mk     = function(c,p,pr) local o=Instance.new(c); if pr then for k,v in pairs(pr) do o[k]=v end end; o.Parent=p; return o end
    corner = function(i,r) mk("UICorner",i,{CornerRadius=UDim.new(0,r or 5)}) end   -- 0.5 ≈ 5px default
    stroke = function(i,c,t) return mk("UIStroke",i,{Color=c or T.card,Thickness=t or 1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border}) end
    pad    = function(i,l,r,t,b) mk("UIPadding",i,{PaddingLeft=UDim.new(0,l or 0),PaddingRight=UDim.new(0,r or 0),PaddingTop=UDim.new(0,t or 0),PaddingBottom=UDim.new(0,b or 0)}) end
    lbl    = function(p,t,s,pos,col) return mk("TextLabel",p,{Text=t,Size=s,Position=pos or UDim2.new(0,0,0,0),TextColor3=col or T.text,BackgroundTransparency=1,Font=Enum.Font.GothamSemibold,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left}) end
    box    = function(p,s,pos,def) local b=mk("TextBox",p,{Size=s,Position=pos or UDim2.new(0,0,0,0),Text=def or "",TextColor3=T.text,BackgroundColor3=T.input,Font=Enum.Font.GothamSemibold,TextSize=11,ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Left,PlaceholderColor3=T.sub}); corner(b,6); pad(b,8,8,0,0); return b end
    btn    = function(p,t,s,pos,col) local b=mk("TextButton",p,{Text=t,Size=s,Position=pos or UDim2.new(0,0,0,0),TextColor3=T.text,BackgroundColor3=col or T.btn,Font=Enum.Font.GothamBold,TextSize=11,BorderSizePixel=0,AutoButtonColor=true}); corner(b,6); return b end
end

-- ===================================================================
-- ENTORNO WORKSPACE
-- ===================================================================
local envF    = mk("Folder", workspace, {Name="KIMIKO_ENV"})
Mouse.TargetFilter = envF
local prevF   = mk("Folder", envF, {Name="Preview"})
local savePrevF = mk("Folder", envF, {Name="SavePreview"})

-- ===================================================================
-- SCREEN GUI PRINCIPAL
-- ===================================================================
local SG = mk("ScreenGui", GP, {Name="KIMIKO_SB", ResetOnSpawn=false, ZIndexBehavior=Enum.ZIndexBehavior.Sibling, DisplayOrder=999})
pcall(function() if syn and syn.protect_gui then syn.protect_gui(SG) end end)

-- Botón toggle (◈)
local ToggleBtn = mk("TextButton", SG, {
    Size=UDim2.new(0,44,0,44), Position=UDim2.new(1,-64,0,24),
    BackgroundColor3=T.panel, TextColor3=T.text, Text="◈", TextSize=22,
    Active=true, Draggable=true
})
corner(ToggleBtn,10); stroke(ToggleBtn,T.accent,1)

-- Ventana principal
local Win = mk("Frame", SG, {
    Size=UDim2.new(0,300,0,440),
    Position=UDim2.new(0.5,0,0.5,0),
    AnchorPoint=Vector2.new(0.5,0.5),
    BackgroundColor3=Color3.new(0,0,0),   -- negro puro
    BorderSizePixel=0, Active=true, ClipsDescendants=true
})
corner(Win, 5)   -- UICorner 0.5 (5px)
stroke(Win, T.card, 1)

ToggleBtn.MouseButton1Click:Connect(function() Win.Visible=not Win.Visible end)

-- ===================================================================
-- COLOR PICKER
-- ===================================================================
local cpCB = nil
local selColor = Color3.fromRGB(255,255,255)
local cpOv, openCP
do
    local function createColorPicker(parentWin)
        local ov=mk("Frame",parentWin,{Size=UDim2.new(1,0,1,0),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0.35,BorderSizePixel=0,Visible=false,ZIndex=50})
        mk("TextButton",ov,{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",BorderSizePixel=0,ZIndex=50,AutoButtonColor=false})
        local WS=200;local SH=18;local WW=240;local WH=30+WS+12+SH+22+46+12+34+12
        local pw=mk("Frame",ov,{Size=UDim2.new(0,WW,0,WH),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,0),BackgroundColor3=T.panel,BorderSizePixel=0,ZIndex=51}); corner(pw,12); stroke(pw,T.accent,1.5)
        mk("TextLabel",pw,{Text="ELEGIR COLOR",Size=UDim2.new(1,-20,0,20),Position=UDim2.new(0,10,0,6),TextColor3=T.text,BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextSize=12,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=52})
        local wY=30
        local wC=mk("Frame",pw,{Size=UDim2.new(0,WS,0,WS),AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,wY),BackgroundColor3=Color3.fromRGB(15,15,15),ClipsDescendants=true,BorderSizePixel=0,ZIndex=52}); corner(wC,WS/2)
        -- rueda de color simplificada (celdas)
        do local cell=4;local cells=math.ceil(WS/cell);local center=WS/2;local iW=mk("Frame",wC,{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true,ZIndex=52}); corner(iW,WS/2); for row2=0,cells-1 do for col2=0,cells-1 do local cx2=(col2+0.5)*cell;local cy2=(row2+0.5)*cell;local dx2=cx2-center;local dy2=cy2-center;local dist2=math.sqrt(dx2*dx2+dy2*dy2);if dist2<=center then local a2=math.atan2(dy2,dx2);local h2=(a2/(2*math.pi)+0.5)%1;local s2=math.min(dist2/(center-1),1);mk("Frame",iW,{Size=UDim2.new(0,cell+1,0,cell+1),Position=UDim2.new(0,col2*cell,0,row2*cell),BackgroundColor3=Color3.fromHSV(h2,s2,1),BorderSizePixel=0,ZIndex=52}) end end end end
        local wR=mk("Frame",wC,{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=59}); corner(wR,WS/2); mk("UIStroke",wR,{Color=Color3.fromRGB(80,80,80),Thickness=1.5,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
        local wCur=mk("Frame",wC,{AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.new(0,14,0,14),Position=UDim2.new(0.5,0,0.5,0),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=60}); corner(wCur,7); mk("UIStroke",wCur,{Color=Color3.new(1,1,1),Thickness=2.5,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
        local sY=wY+WS+12
        local sF=mk("Frame",pw,{Size=UDim2.new(1,-20,0,SH),Position=UDim2.new(0,10,0,sY),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=52}); corner(sF,SH/2)
        local sG=mk("UIGradient",sF,{Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),Rotation=0})
        local sCur=mk("Frame",sF,{Size=UDim2.new(0,14,0,SH+6),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(1,0,0.5,0),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=53}); corner(sCur,4); mk("UIStroke",sCur,{Color=Color3.fromRGB(80,80,80),Thickness=1.5,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
        mk("TextLabel",pw,{Text="Brillo",Size=UDim2.new(0,60,0,14),Position=UDim2.new(0,10,0,sY+SH+3),TextColor3=T.sub,BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=9,ZIndex=52})
        local pY=sY+SH+20
        local pC=mk("Frame",pw,{Size=UDim2.new(0,40,0,40),AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,10,0,pY+20),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=52}); corner(pC,20); stroke(pC,T.text,1.5)
        local hxL=mk("TextLabel",pw,{Text="#FFFFFF",Size=UDim2.new(0,140,0,16),Position=UDim2.new(0,58,0,pY+8),TextColor3=T.text,BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextSize=12,ZIndex=52})
        local rgbL=mk("TextLabel",pw,{Text="255, 255, 255",Size=UDim2.new(0,140,0,14),Position=UDim2.new(0,58,0,pY+26),TextColor3=T.sub,BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=9,ZIndex=52})
        local bY=pY+46
        local bOk=btn(pw,"Aceptar",UDim2.new(0,108,0,30),UDim2.new(0,10,0,bY),T.build); local bCnl=btn(pw,"Cancelar",UDim2.new(0,108,0,30),UDim2.new(1,-118,0,bY),T.danger)
        bOk.ZIndex=52; bCnl.ZIndex=52
        local pH,pS,pV=0,0,1; local dW,dS=false,false
        local function refGrad() sG.Color=ColorSequence.new(Color3.fromHSV(pH,pS,1),Color3.new(0,0,0)) end
        local function updCol() local col=Color3.fromHSV(pH,pS,pV); pC.BackgroundColor3=col; local r=math.round(col.R*255);local g=math.round(col.G*255);local b=math.round(col.B*255); hxL.Text=string.format("#%02X%02X%02X",r,g,b); rgbL.Text=string.format("%d, %d, %d",r,g,b); refGrad(); return col end
        local function refWCur() local a=(pH-0.5)*2*math.pi; local nx=0.5+0.5*pS*math.cos(a); local ny=0.5+0.5*pS*math.sin(a); wCur.Position=UDim2.new(nx,0,ny,0) end
        local cpLive=nil
        local function setHSV(h,s,v) pH=math.clamp(h,0,1);pS=math.clamp(s,0,1);pV=math.clamp(v,0,1); refWCur(); sCur.Position=UDim2.new(1-pV,0,0.5,0); updCol(); if cpLive then cpLive(Color3.fromHSV(pH,pS,pV)) end end
        local function onWI(pos) local ab=wC.AbsolutePosition;local sz=wC.AbsoluteSize;local rad=sz.X/2;local dx=(pos.X-ab.X)-rad;local dy=(pos.Y-ab.Y)-rad;local dist=math.sqrt(dx*dx+dy*dy);if dist>rad then local k=rad/dist;dx,dy=dx*k,dy*k end;local angle=math.atan2(dy,dx);setHSV((angle/(2*math.pi)+0.5)%1,math.min(math.sqrt(dx*dx+dy*dy)/rad,1),pV) end
        local function onSI(pos) local ab=sF.AbsolutePosition;local sw=sF.AbsoluteSize.X;local relX=math.clamp((pos.X-ab.X)/math.max(1,sw),0,1);setHSV(pH,pS,1-relX) end
        wC.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then dW=true; onWI(inp.Position) end end)
        wC.InputEnded:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then dW=false end end)
        sF.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then dS=true; onSI(inp.Position) end end)
        sF.InputEnded:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then dS=false end end)
        UserInputService.InputChanged:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch then if dW then onWI(inp.Position) end; if dS then onSI(inp.Position) end end end)
        UserInputService.InputEnded:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then dW=false; dS=false end end)
        bOk.MouseButton1Click:Connect(function() local col=updCol(); ov.Visible=false; cpLive=nil; if cpCB then cpCB(col) end end)
        bCnl.MouseButton1Click:Connect(function() cpLive=nil; ov.Visible=false end)
        local function openPicker(cur,cb,live)
            cpCB=cb; cpLive=live; ov.Visible=true
            task.defer(function() local h,s,v=Color3.toHSV(cur); setHSV(h,s,v) end)
        end
        return ov, openPicker
    end
    cpOv, openCP = createColorPicker(Win)
    cpOv.ZIndex = 50
end

-- ===================================================================
-- HEADER (fondo negro puro con UICorner 5px)
-- ===================================================================
local HDR_H = 46
local Hdr = mk("Frame", Win, {
    Size=UDim2.new(1,0,0,HDR_H),
    BackgroundColor3=Color3.new(0,0,0),   -- negro puro
    BorderSizePixel=0
})
corner(Hdr, 5)   -- UICorner 0.5 (5px)

local hdrT = lbl(Hdr,"KIMIKO HUB",UDim2.new(0,100,0,16),UDim2.new(0,12,0,6),T.text); hdrT.Font=Enum.Font.GothamBold; hdrT.TextSize=14
local hdrS = lbl(Hdr,"Build A Boat",UDim2.new(1,-120,0,14),UDim2.new(0,116,0,8),T.sub); hdrS.Font=Enum.Font.Gotham; hdrS.TextSize=9

-- Drag del header
do
    local drag,ds,dp=false,nil,nil
    Hdr.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then drag=true; ds=inp.Position; dp=Win.Position; inp.Changed:Connect(function() if inp.UserInputState==Enum.UserInputState.End then drag=false end end) end end)
    UserInputService.InputChanged:Connect(function(inp) if drag and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then local d=inp.Position-ds; Win.Position=UDim2.new(dp.X.Scale,dp.X.Offset+d.X,dp.Y.Scale,dp.Y.Offset+d.Y) end end)
end

-- Botón minimizar/expandir en el header
local minimized = false
local minBtn = mk("TextButton", Hdr, {
    Size=UDim2.new(0,28,0,22), Position=UDim2.new(1,-34,0.5,-11),
    BackgroundColor3=T.btnAlt, Text="—", TextColor3=T.text,
    Font=Enum.Font.GothamBold, TextSize=13, BorderSizePixel=0
})
corner(minBtn, 6)
local WinNormalSize = UDim2.new(0,300,0,440)
local WinMinSize    = UDim2.new(0,300,0,HDR_H)
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        Win.Size=WinMinSize; minBtn.Text="□"
    else
        Win.Size=WinNormalSize; minBtn.Text="—"
    end
end)

-- ===================================================================
-- TAB BAR
-- ===================================================================
local TabBar = mk("Frame", Hdr, {Size=UDim2.new(1,-16,0,22),Position=UDim2.new(0,8,0,HDR_H-24),BackgroundTransparency=1})
mk("UIListLayout",TabBar,{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6)})

local Body = mk("Frame", Win, {Size=UDim2.new(1,0,1,-HDR_H),Position=UDim2.new(0,0,0,HDR_H),BackgroundTransparency=1})

-- ===================================================================
-- ESTADO GLOBAL COMPARTIDO
-- ===================================================================
local gbRunning = {value=false}   -- compartida entre módulos

-- ===================================================================
-- ENTORNO COMPARTIDO PARA MÓDULOS
-- ===================================================================
local ENV = {
    -- UI helpers
    mk=mk, corner=corner, stroke=stroke, pad=pad, lbl=lbl, box=box, btn=btn,
    T=T, SG=SG, Win=Win, Body=Body,
    -- Color picker
    openCP=openCP,
    -- Servicios
    RunService=RunService, UserInputService=UserInputService,
    Camera=Camera, Mouse=Mouse, Players=Players,
    LP=LP,
    -- Mundo
    envF=envF, prevF=prevF, savePrevF=savePrevF,
    -- Zonas
    ZONES=ZONES, ZONE_DATA=ZONE_DATA,
    getZoneOrientCF=getZoneOrientCF,
    getZoneCFForPos=getZoneCFForPos,
    zoneDeltaRot=zoneDeltaRot,
    -- Player helpers
    getTool=getTool, equipTool=equipTool,
    userFolder=userFolder, dataFolder=dataFolder,
    myRefPos=myRefPos, closestZone=closestZone,
    captureBuild=captureBuild, countPB=countPB,
    getTeamColor=getTeamColor, isLdr=isLdr,
    isSharing=isSharing, getMyLeader=getMyLeader,
    getShareSource=getShareSource,
    getActiveData=getActiveData, getActiveTool=getActiveTool,
    paintBatch=paintBatch,
    -- Iconos
    ICON_MOVE=ICON_MOVE, ICON_ROT=ICON_ROT, ICON_LEADER=ICON_LEADER,
    -- File system
    FSys=FSys, FS2=FS2, HttpService=HttpService,
    readBF=readBF, writeBF=writeBF,
    ORD=ORD, sOrd=sOrd, lOrd=lOrd, syncOrd=syncOrd,
    addSaveOrd=addSaveOrd, delSaveOrd=delSaveOrd,
    -- Saves
    Saves=Saves, readSaves=readSaves, writeSaves=writeSaves,
    autoName=autoName, reloadSaves=reloadSaves, GKEY=GKEY,
    -- Estado global
    gbRunning=gbRunning,
}

-- ===================================================================
-- CARGAR MÓDULOS
-- ===================================================================
local FormasModule = loadModule(MOD_FORMAS)
local BuildsModule = loadModule(MOD_BUILDS)

if not FormasModule or not BuildsModule then
    warn("[KimikoHub] No se pudieron cargar uno o más módulos. Revisa la URL de GitHub.")
    -- Crear un label de error en la ventana
    mk("TextLabel",Body,{Size=UDim2.new(1,0,0,40),Position=UDim2.new(0,0,0,10),Text="Error al cargar módulos.\nRevisa GITHUB_RAW en main.lua",TextColor3=T.danger,BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextSize=11,TextXAlignment=Enum.TextXAlignment.Center})
    return
end

local formasAPI = FormasModule.init(ENV)
local buildsAPI = BuildsModule.init(ENV)

-- ===================================================================
-- TABS
-- ===================================================================
local Pages   = {Formas=formasAPI.page, Builds=buildsAPI.page}
local TabBtns = {}
local activeTab = "Formas"

local function setTab(t)
    activeTab=t
    for k,pg in pairs(Pages) do pg.Visible=(k==t) end
    for k,tb in pairs(TabBtns) do
        tb.BackgroundColor3=(k==t) and T.accent or T.card
        tb.TextColor3=(k==t) and T.bg or T.text
    end
    if t=="Formas" then
        -- Ocultar previews de builds
        buildsAPI.hidePreview()
        buildsAPI.SaveHandles.Visible=false
        buildsAPI.SaveArc.Visible=false
        -- Mostrar/refrescar formas
        formasAPI.markPreview()
    else
        -- Ocultar previews de formas
        formasAPI.hidePreview()
        formasAPI.handles.Visible=false
        formasAPI.arc.Visible=false
        -- Recargar saves
        buildsAPI.reloadAndRender()
    end
end

-- Crear botones de tab
for _,td in ipairs({{"Formas","Formas"},{"Builds","Mis Builds"}}) do
    local b=mk("TextButton",TabBar,{Size=UDim2.new(0.5,-3,1,0),Text=td[2],TextColor3=T.text,TextSize=10,Font=Enum.Font.GothamBold,BackgroundColor3=T.card})
    corner(b,6); TabBtns[td[1]]=b
    b.MouseButton1Click:Connect(function() setTab(td[1]) end)
end

-- ===================================================================
-- INIT
-- ===================================================================
setTab("Formas")
Win.Visible=true
