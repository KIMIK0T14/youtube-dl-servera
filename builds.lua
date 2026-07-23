-- builds.lua
local BuildsModule = {}

function BuildsModule.init(ENV)
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
    local UserInputService = ENV.UserInputService
    local Camera      = ENV.Camera
    local Mouse       = ENV.Mouse
    local envF        = ENV.envF
    local savePrevF   = ENV.savePrevF
    local LP          = ENV.LP
    local Players     = ENV.Players
    local closestZone = ENV.closestZone
    local myRefPos    = ENV.myRefPos
    local ZONES       = ENV.ZONES
    local ZONE_DATA   = ENV.ZONE_DATA
    local getZoneOrientCF = ENV.getZoneOrientCF
    local getZoneCFForPos = ENV.getZoneCFForPos
    local zoneDeltaRot    = ENV.zoneDeltaRot
    local getTool     = ENV.getTool
    local equipTool   = ENV.equipTool
    local userFolder  = ENV.userFolder
    local dataFolder  = ENV.dataFolder
    local captureBuild = ENV.captureBuild
    local countPB     = ENV.countPB
    local isLdr       = ENV.isLdr
    local getTeamColor = ENV.getTeamColor
    local isSharing   = ENV.isSharing
    local paintBatch  = ENV.paintBatch
    local ICON_MOVE   = ENV.ICON_MOVE
    local ICON_ROT    = ENV.ICON_ROT
    local ICON_LEADER = ENV.ICON_LEADER
    local FSys        = ENV.FSys
    local FS2         = ENV.FS2
    local HttpService = ENV.HttpService
    local readBF      = ENV.readBF
    local writeBF     = ENV.writeBF
    local ORD         = ENV.ORD
    local sOrd        = ENV.sOrd
    local lOrd        = ENV.lOrd
    local syncOrd     = ENV.syncOrd
    local addSaveOrd  = ENV.addSaveOrd
    local delSaveOrd  = ENV.delSaveOrd
    local Saves       = ENV.Saves
    local readSaves   = ENV.readSaves
    local writeSaves  = ENV.writeSaves
    local autoName    = ENV.autoName
    local reloadSaves = ENV.reloadSaves
    local GKEY        = ENV.GKEY
    local gbRunningRef = ENV.gbRunning

    local PageSave = mk("ScrollingFrame", Body, {
        Size = UDim2.new(1,0,1,0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = T.purple,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0,0,0,0),
        Visible = false
    })
    mk("UIListLayout", PageSave, {Padding=UDim.new(0,6), SortOrder=Enum.SortOrder.LayoutOrder})
    pad(PageSave, 10, 10, 10, 10)

    local myBaseCF    = nil
    local selPlayer   = LP.Name
    local selSaveIdx  = nil
    local placePosV   = nil
    local placeScale  = 1
    local placeRot    = CFrame.identity
    local saveToolMode = "move"
    local savePrevOn  = true
    local savePrevAlpha = 0.3
    local useCZ       = true
    local SaveUI      = {}
    local whoVis      = false
    local whoFrame    = nil
    local whoBtn      = nil
    local whoInner    = nil
    local curUID      = LP.UserId
    local curDN       = "Yo"
    local curUN       = LP.Name
    local saveBuildState = {running=false, cancel=false}

    local PURPLE_GAMER = Color3.fromRGB(170, 0, 255)

    local function sec(parent, order)
        local f=mk("Frame",parent,{Size=UDim2.new(1,0,0,1),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=T.card,BorderSizePixel=0,LayoutOrder=order or 0})
        corner(f,8); pad(f,10,10,8,10); mk("UIListLayout",f,{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
        return f
    end

    local cCache = {}
    local function buildCenter(sv)
        if not sv or not sv.data or not sv.data.Block or #sv.data.Block==0 then return Vector3.zero end
        if cCache[sv] then return cCache[sv] end
        local minv=Vector3.new(math.huge,math.huge,math.huge); local maxv=Vector3.new(-math.huge,-math.huge,-math.huge)
        for _,pd in ipairs(sv.data.Block) do local p=Vector3.new(pd.RelX or 0,pd.RelY or 0,pd.RelZ or 0); minv=Vector3.new(math.min(minv.X,p.X),math.min(minv.Y,p.Y),math.min(minv.Z,p.Z)); maxv=Vector3.new(math.max(maxv.X,p.X),math.max(maxv.Y,p.Y),math.max(maxv.Z,p.Z)) end
        local c=(minv+maxv)/2; cCache[sv]=c; return c
    end
    local _lastDelta={sv=nil,dst=nil,delta=CFrame.identity}
    local function getSaveDelta(sv)
        local mz=closestZone(myRefPos()); local mzN=mz and mz.Name or"WhiteZone"
        local sN=(sv and sv.data and sv.data.SrcZoneName) or"WhiteZone"
        if _lastDelta.sv==sv and _lastDelta.dst==mzN then return _lastDelta.delta end
        local delta=zoneDeltaRot(sN,mzN); _lastDelta={sv=sv,dst=mzN,delta=delta}; return delta
    end
    local function curPlacePos()
        if placePosV then return placePosV end
        local z=closestZone(myRefPos()); if z then return z.Position+Vector3.new(0,z.Size.Y/2+1,0) end
        return myRefPos()
    end

    local saveDummy = mk("Part", envF, {Size=Vector3.new(4,4,4),Transparency=1,Anchored=true,CanCollide=false,CanQuery=false,Material=Enum.Material.Plastic,Position=Vector3.new(0,-9999,0)})
    local SaveHandles = mk("Handles", SG, {
        Adornee = saveDummy,
        Style   = Enum.HandlesStyle.Movement,
        Color3  = PURPLE_GAMER,
        Visible = false,
    })
    pcall(function() SaveHandles.AlwaysOnTop = true end)

    local saveArcAdornee = mk("Part", envF, {Size=Vector3.new(12,12,12),Transparency=1,Anchored=true,CanCollide=false,CanQuery=false,Material=Enum.Material.Plastic,Position=Vector3.new(0,-9999,0)})
    local SaveArc = mk("ArcHandles", SG, {
        Adornee = saveArcAdornee,
        Color3  = PURPLE_GAMER,
        Visible = false,
    })
    pcall(function() SaveArc.AlwaysOnTop = true end)

    local function updSaveHandles()
        local hasSel=selSaveIdx~=nil and savePrevOn
        if not PageSave.Visible then SaveHandles.Visible=false; SaveArc.Visible=false; return end
        SaveHandles.Visible=hasSel and saveToolMode=="move"
        SaveArc.Visible    =hasSel and saveToolMode=="rotate"
        if hasSel then
            local pos=curPlacePos()
            saveDummy.CFrame=CFrame.new(pos)*placeRot
            saveArcAdornee.CFrame=CFrame.new(pos)*placeRot
        else
            saveArcAdornee.Position=Vector3.new(0,-9999,0)
        end
    end

    local savePool={}
    local renderSavePrev
    renderSavePrev = function()
        local sv=selSaveIdx and Saves[selSaveIdx]
        if not sv or not sv.data or not sv.data.Block or not savePrevOn then
            for _,p in ipairs(savePool) do p.Transparency=1; p.Size=Vector3.new(0.05,0.05,0.05) end
            saveDummy.Position=Vector3.new(0,-9999,0); saveArcAdornee.Position=Vector3.new(0,-9999,0)
            SaveHandles.Visible=false; SaveArc.Visible=false; return
        end
        local pos=curPlacePos(); local delta=getSaveDelta(sv); local center=buildCenter(sv); local cAdj=delta*center
        local blocks=sv.data.Block; local n=0
        local minv=Vector3.new(math.huge,math.huge,math.huge); local maxv=Vector3.new(-math.huge,-math.huge,-math.huge)
        for _,pd in ipairs(blocks) do
            n=n+1; local p=savePool[n]
            if not p then p=mk("Part",savePrevF,{Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,CastShadow=false,Material=Enum.Material.Plastic}); savePool[n]=p end
            local relPos=Vector3.new(pd.RelX,pd.RelY,pd.RelZ); local relRot=CFrame.Angles(math.rad(pd.RotX or 0),math.rad(pd.RotY or 0),math.rad(pd.RotZ or 0))
            local rPA=delta*relPos; local rRA=(delta-delta.Position)*relRot
            local offset=(rPA-cAdj)*placeScale; local rotOff=placeRot*offset
            local bCF=CFrame.new(pos+rotOff)*placeRot*rRA; local bSz=Vector3.new(pd.SizeX or 2,pd.SizeY or 2,pd.SizeZ or 2)*placeScale
            p.Size=bSz; p.CFrame=bCF
            p.Material = Enum.Material[pd.Material] or Enum.Material.Plastic
            p.Color=(pd.ColorR and Color3.new(pd.ColorR,pd.ColorG,pd.ColorB)) or T.purple
            p.Transparency=savePrevAlpha
            local hS=bSz/2; local pP=bCF.Position
            minv=Vector3.new(math.min(minv.X,pP.X-hS.X),math.min(minv.Y,pP.Y-hS.Y),math.min(minv.Z,pP.Z-hS.Z))
            maxv=Vector3.new(math.max(maxv.X,pP.X+hS.X),math.max(maxv.Y,pP.Y+hS.Y),math.max(maxv.Z,pP.Z+hS.Z))
        end
        for i=n+1,#savePool do savePool[i].Transparency=1; savePool[i].Size=Vector3.new(0.05,0.05,0.05) end
        if minv.X~=math.huge then local sz=maxv-minv; saveDummy.Size=Vector3.new(math.clamp(sz.X,4,200),math.clamp(sz.Y,4,200),math.clamp(sz.Z,4,200)); saveArcAdornee.Size=saveDummy.Size else saveDummy.Size=Vector3.new(4,4,4) end
        saveDummy.CFrame=CFrame.new(pos)*placeRot; saveArcAdornee.CFrame=CFrame.new(pos)*placeRot
        updSaveHandles()
    end

    do
        local sDrag=false; local sDragOP=nil; local sSavedCam=nil
        local sArcDrag=false; local sArcStartRot=nil; local sArcSavedCam=nil
        SaveHandles.MouseButton1Down:Connect(function() if not PageSave.Visible or not selSaveIdx then return end; sDrag=true; sDragOP=curPlacePos(); sSavedCam=Camera.CFrame; Camera.CameraType=Enum.CameraType.Scriptable end)
        SaveHandles.MouseDrag:Connect(function(face,dist) if not sDrag or not sDragOP then return end; local st=tonumber(SaveUI.saveMoveStep and SaveUI.saveMoveStep.Text) or 0; if st<0 then st=0 end; local d=(st>0)and(math.floor(dist/st+0.5)*st)or dist; local dir=(CFrame.new(sDragOP)*placeRot):VectorToWorldSpace(Vector3.FromNormalId(face)); placePosV=sDragOP+dir*d; useCZ=false; renderSavePrev() end)
        SaveHandles.MouseButton1Up:Connect(function() if not sDrag then return end; sDrag=false; sSavedCam=nil; Camera.CameraType=Enum.CameraType.Custom end)
        SaveArc.MouseButton1Down:Connect(function() if not PageSave.Visible or not selSaveIdx then return end; sArcDrag=true; sArcStartRot=placeRot; sArcSavedCam=Camera.CFrame; Camera.CameraType=Enum.CameraType.Scriptable end)
        SaveArc.MouseDrag:Connect(function(axis,relAngle) if not sArcDrag then return end; local av=(axis==Enum.Axis.X and Vector3.xAxis)or(axis==Enum.Axis.Y and Vector3.yAxis)or Vector3.zAxis; local st=tonumber(SaveUI.saveRotStep and SaveUI.saveRotStep.Text) or 0; if st<0 then st=0 end; local snapped=(st>0)and math.rad(math.floor(math.deg(relAngle)/st+0.5)*st)or relAngle; placeRot=sArcStartRot*CFrame.fromAxisAngle(av,snapped); renderSavePrev() end)
        SaveArc.MouseButton1Up:Connect(function() if not sArcDrag then return end; sArcDrag=false; sArcSavedCam=nil; Camera.CameraType=Enum.CameraType.Custom end)
        RunService.RenderStepped:Connect(function() if sDrag and sSavedCam then Camera.CFrame=sSavedCam end; if sArcDrag and sArcSavedCam then Camera.CFrame=sArcSavedCam end end)
    end

    local selTickToken = nil
    local refreshWho
    do
        local whoRows={}; local whoEmptyL=nil
        local function listTC(un)
            if un==LP.Name then return T.btnAlt end
            for _,p in ipairs(Players:GetPlayers()) do if p.Name==un and p.Team and p.Team.TeamColor then local tc=p.Team.TeamColor.Color; return Color3.new(tc.R*0.25,tc.G*0.25,tc.B*0.25) end end
            return T.btnAlt
        end
        local function whoMembers()
            local m={}; local allP=Players:GetPlayers()
            table.sort(allP,function(a,b) local al,bl=isLdr(a.Name),isLdr(b.Name); if al~=bl then return al end; local at,bt=a.Team and a.Team.TeamColor.Number or -1,b.Team and b.Team.TeamColor.Number or -1; if at~=bt then return at<bt end; return a.Name<b.Name end)
            for _,p in ipairs(allP) do if p.Name~=selPlayer then m[#m+1]={uid=p.UserId,dname=p.DisplayName or p.Name,uname=p.Name} end end
            return m
        end
        local function buildWhoRow(mem)
            local row=mk("Frame",whoInner,{Size=UDim2.new(1,0,0,36),BackgroundColor3=listTC(mem.uname),BorderSizePixel=0}); corner(row,8)
            local isL=isLdr(mem.uname); if isL then mk("ImageLabel",row,{Name="LdrIco",Size=UDim2.new(0,16,0,16),Position=UDim2.new(0,3,0.5,-8),BackgroundTransparency=1,Image=ICON_LEADER,ZIndex=3}) end
            local avX2=isL and 22 or 5; local av=mk("ImageLabel",row,{Name="Avatar",Size=UDim2.new(0,26,0,26),Position=UDim2.new(0,avX2,0.5,-13),BackgroundColor3=T.card,BorderSizePixel=0}); corner(av,6)
            task.spawn(function() local ok2,url=pcall(function() return Players:GetUserThumbnailAsync(mem.uid,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size48x48) end); if ok2 then av.Image=url end end)
            local nX2=avX2+30
            mk("TextLabel",row,{Position=UDim2.new(0,nX2,0,4),Size=UDim2.new(1,-100,0,14),Text=mem.dname,TextColor3=T.text,BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left})
            mk("TextLabel",row,{Position=UDim2.new(0,nX2,0,20),Size=UDim2.new(1,-100,0,12),Text="@"..mem.uname,TextColor3=T.sub,BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=9,TextXAlignment=Enum.TextXAlignment.Left})
            local bkL=mk("TextLabel",row,{Position=UDim2.new(1,-62,0,0),Size=UDim2.new(0,60,1,0),Text="...",TextColor3=T.sub,BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextSize=9,TextXAlignment=Enum.TextXAlignment.Right})
            local rb=mk("TextButton",row,{Size=UDim2.new(1,0,1,0),Text="",BackgroundTransparency=1})
            rb.MouseButton1Click:Connect(function()
                selPlayer=mem.uname; curUID=mem.uid; curDN=mem.dname; curUN=mem.uname
                whoVis=false; if whoFrame then whoFrame.Visible=false end
                if whoBtn then for _,ch in ipairs(whoBtn:GetChildren()) do if ch:IsA("TextLabel")and(ch.Text=="▲"or ch.Text=="▼") then ch.Text="▼" end end end
                if whoBtn then whoBtn.BackgroundColor3=getTeamColor(curUN) end
                refreshWho()
            end)
            return {row=row,blockLbl=bkL,lastCount=nil,lastTC=nil}
        end
        refreshWho = function()
            if not whoInner then return end
            local members=whoMembers(); local present={}; for _,m in ipairs(members) do present[m.uid]=m end
            for uid,rec in pairs(whoRows) do if not present[uid] then rec.row:Destroy(); whoRows[uid]=nil end end
            local order=0
            for _,m in ipairs(members) do
                order=order+1; local rec=whoRows[m.uid]
                if not rec then rec=buildWhoRow(m); whoRows[m.uid]=rec end
                rec.row.LayoutOrder=order
                local tc=listTC(m.uname); if rec.lastTC~=tc then rec.lastTC=tc; rec.row.BackgroundColor3=tc end
                local bc=countPB(m.uname); if rec.lastCount~=bc then rec.lastCount=bc; rec.blockLbl.Text=bc>0 and tostring(bc) or"0"; rec.blockLbl.TextColor3=bc>0 and T.ok or T.sub end
                local lIco=rec.row:FindFirstChild("LdrIco"); local isL=isLdr(m.uname)
                if isL and not lIco then mk("ImageLabel",rec.row,{Name="LdrIco",Size=UDim2.new(0,16,0,16),Position=UDim2.new(0,3,0.5,-8),BackgroundTransparency=1,Image=ICON_LEADER,ZIndex=3}) elseif not isL and lIco then lIco:Destroy() end
                local av=rec.row:FindFirstChild("Avatar"); if av then av.Position=UDim2.new(0,isL and 22 or 5,0.5,-13) end
            end
            if #members==0 then if not whoEmptyL then whoEmptyL=mk("TextLabel",whoInner,{Size=UDim2.new(1,0,0,24),LayoutOrder=1,Text="Eres el único jugador",TextColor3=T.sub,BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=10,TextXAlignment=Enum.TextXAlignment.Center}) end
            elseif whoEmptyL then whoEmptyL:Destroy(); whoEmptyL=nil end
        end
    end

    local function startSelTicker()
        if selTickToken then selTickToken=false end
        local tok={}; selTickToken=tok
        task.spawn(function()
            while selTickToken==tok and SG and SG.Parent do
                task.wait(1); if selTickToken~=tok then break end
                if not PageSave.Visible then continue end
                if whoBtn and whoBtn.Parent and not whoVis then
                    local bc=countPB(curUN); local isL=isLdr(curUN)
                    local lIco=whoBtn:FindFirstChild("LdrIco")
                    if isL and not lIco then mk("ImageLabel",whoBtn,{Name="LdrIco",Size=UDim2.new(0,14,0,14),Position=UDim2.new(0,4,0.5,-7),BackgroundTransparency=1,Image=ICON_LEADER,ZIndex=3}) elseif not isL and lIco then lIco:Destroy() end
                    local av=whoBtn:FindFirstChild("Avatar"); if av then av.Position=UDim2.new(0,isL and 20 or 4,0.5,-11) end
                    for _,ch in ipairs(whoBtn:GetChildren()) do if ch:IsA("TextLabel") and ch.TextXAlignment==Enum.TextXAlignment.Left then ch.Text=curDN.." (@"..curUN..") · "..bc; break end end
                    whoBtn.BackgroundColor3=getTeamColor(curUN)
                end
                if whoVis then refreshWho() end
            end
        end)
    end

    local function setWhoBtn(uid,dn,un)
        if not whoBtn then return end
        for _,c in ipairs(whoBtn:GetChildren()) do if not c:IsA("UICorner") and not c:IsA("UIStroke") then c:Destroy() end end
        whoBtn.BackgroundColor3=getTeamColor(un)
        local isL=isLdr(un); if isL then mk("ImageLabel",whoBtn,{Name="LdrIco",Size=UDim2.new(0,14,0,14),Position=UDim2.new(0,4,0.5,-7),BackgroundTransparency=1,Image=ICON_LEADER,ZIndex=3}) end
        local avX=isL and 20 or 4; local av=mk("ImageLabel",whoBtn,{Name="Avatar",Size=UDim2.new(0,22,0,22),Position=UDim2.new(0,avX,0.5,-11),BackgroundColor3=T.card,BorderSizePixel=0}); corner(av,6)
        task.spawn(function() local ok2,url=pcall(function() return Players:GetUserThumbnailAsync(uid,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size48x48) end); if ok2 then av.Image=url end end)
        local nX=avX+26; local nL=mk("TextLabel",whoBtn,{Position=UDim2.new(0,nX,0,0),Size=UDim2.new(1,-nX-18,1,0),Text=dn.." (@"..un..")",TextColor3=T.text,BackgroundTransparency=1,Font=Enum.Font.GothamSemibold,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd})
        mk("TextLabel",whoBtn,{Position=UDim2.new(1,-18,0,0),Size=UDim2.new(0,16,1,0),Text=whoVis and"▲"or"▼",TextColor3=T.sub,BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextSize=10,TextXAlignment=Enum.TextXAlignment.Center})
        task.spawn(function() local bc=countPB(un); if nL and nL.Parent then nL.Text=dn.." (@"..un..") · "..bc end end)
    end

    local secSave = sec(PageSave, 3)
    mk("TextLabel",secSave,{Size=UDim2.new(1,0,0,14),Text="Seleccionar jugador",TextColor3=T.sub,BackgroundTransparency=1,Font=Enum.Font.GothamSemibold,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=0})
    local playerRow=mk("Frame",secSave,{Size=UDim2.new(1,0,0,30),BackgroundTransparency=1,LayoutOrder=1})
    whoBtn=mk("TextButton",playerRow,{Size=UDim2.new(1,0,0,28),Position=UDim2.new(0,0,0,0),BackgroundColor3=T.input,BorderSizePixel=0,Text="",TextXAlignment=Enum.TextXAlignment.Left}); corner(whoBtn,8); stroke(whoBtn,T.sub,1)
    setWhoBtn(LP.UserId,"Yo",LP.Name)
    whoFrame=mk("Frame",secSave,{Size=UDim2.new(1,0,0,1),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=T.card,BorderSizePixel=0,Visible=false,LayoutOrder=2}); corner(whoFrame,8); stroke(whoFrame,T.sub,1); pad(whoFrame,4,4,4,4)
    whoInner=mk("Frame",whoFrame,{Size=UDim2.new(1,0,0,1),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1}); mk("UIListLayout",whoInner,{Padding=UDim.new(0,3)})
    whoBtn.MouseButton1Click:Connect(function()
        whoVis=not whoVis; whoFrame.Visible=whoVis
        if whoVis then refreshWho(); task.spawn(function() while whoVis and whoFrame.Parent do task.wait(1); if not whoVis then break end; refreshWho() end end) end
        for _,ch in ipairs(whoBtn:GetChildren()) do if ch:IsA("TextLabel")and(ch.Text=="▲"or ch.Text=="▼") then ch.Text=whoVis and"▲"or"▼" end end
    end)

    local saveRow=mk("Frame",secSave,{Size=UDim2.new(1,0,0,28),BackgroundTransparency=1,LayoutOrder=3})
    SaveUI.nameInp=box(saveRow,UDim2.new(1,-80,0,26),UDim2.new(0,0,0,0),""); SaveUI.nameInp.PlaceholderText="Nombre del build..."
    SaveUI.btnSaveNow=btn(saveRow,"Captura",UDim2.new(0,76,0,26),UDim2.new(1,-74,0,0),T.build); SaveUI.btnSaveNow.TextSize=10
    lbl(secSave,"Mis Builds",UDim2.new(1,0,0,12),nil,T.sub).LayoutOrder=4
    SaveUI.listScroll=mk("ScrollingFrame",secSave,{Size=UDim2.new(1,0,0,20),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=T.purple,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(0,0,0,0),LayoutOrder=5}); pad(SaveUI.listScroll,2,2,2,2)
    SaveUI.listCont=mk("Frame",SaveUI.listScroll,{Size=UDim2.new(1,0,0,1),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1}); mk("UIListLayout",SaveUI.listCont,{Padding=UDim.new(0,4)})

    local secPrev = sec(PageSave, 4)

    local rSP=mk("Frame",secPrev,{Size=UDim2.new(1,0,0,28),BackgroundTransparency=1,LayoutOrder=2})
    SaveUI.BtnSavePrev=btn(rSP,"Vista previa: On",UDim2.new(1,-80,1,0),nil,T.accent); SaveUI.BtnSavePrev.TextColor3=T.bg
    local spAlphaFrame=mk("Frame",rSP,{Size=UDim2.new(0,76,1,0),Position=UDim2.new(1,-76,0,0),BackgroundColor3=T.btnAlt,BorderSizePixel=0}); corner(spAlphaFrame,6)
    local spAlphaDown=btn(spAlphaFrame,"-",UDim2.new(0,22,1,0),UDim2.new(0,0,0,0),T.btnAlt)
    local spAlphaLbl=lbl(spAlphaFrame,math.floor(savePrevAlpha*100).."%",UDim2.new(0,28,1,0),UDim2.new(0,22,0,0),T.text); spAlphaLbl.TextXAlignment=Enum.TextXAlignment.Center; spAlphaLbl.Font=Enum.Font.GothamBold; spAlphaLbl.TextSize=10
    local spAlphaUp=btn(spAlphaFrame,"+",UDim2.new(0,22,1,0),UDim2.new(1,-22,0,0),T.btnAlt)
    local function setSPAlpha(v)
        savePrevAlpha=math.clamp(v,0,0.95)
        spAlphaLbl.Text=math.floor(savePrevAlpha*100).."%"
        renderSavePrev()
    end
    spAlphaDown.MouseButton1Click:Connect(function() setSPAlpha(savePrevAlpha-0.10) end)
    spAlphaUp.MouseButton1Click:Connect(function()   setSPAlpha(savePrevAlpha+0.10) end)

    local sTRow=mk("Frame",secPrev,{Size=UDim2.new(1,0,0,26),BackgroundTransparency=1,LayoutOrder=4})
    SaveUI.BtnSaveMove=btn(sTRow,"",UDim2.new(0,38,0,24),UDim2.new(0,0,0,0),T.btn); mk("ImageLabel",SaveUI.BtnSaveMove,{Size=UDim2.new(0,18,0,18),Position=UDim2.new(0.5,-9,0.5,-9),BackgroundTransparency=1,Image=ICON_MOVE})
    SaveUI.saveMoveStep=box(sTRow,UDim2.new(0,44,0,24),UDim2.new(0,42,0,0),"1"); SaveUI.saveMoveStep.TextXAlignment=Enum.TextXAlignment.Center
    SaveUI.BtnSaveRot=btn(sTRow,"",UDim2.new(0,38,0,24),UDim2.new(0,92,0,0),T.btnAlt); mk("ImageLabel",SaveUI.BtnSaveRot,{Size=UDim2.new(0,18,0,18),Position=UDim2.new(0.5,-9,0.5,-9),BackgroundTransparency=1,Image=ICON_ROT})
    SaveUI.saveRotStep=box(sTRow,UDim2.new(0,44,0,24),UDim2.new(0,134,0,0),"15"); SaveUI.saveRotStep.TextXAlignment=Enum.TextXAlignment.Center
    SaveUI.btnScaleDown=btn(sTRow,"-",UDim2.new(0,22,0,24),UDim2.new(1,-72,0,0),T.btnAlt)
    SaveUI.scaleLbl=lbl(sTRow,"1.0x",UDim2.new(0,26,0,24),UDim2.new(1,-48,0,0),T.text); SaveUI.scaleLbl.TextXAlignment=Enum.TextXAlignment.Center
    SaveUI.btnScaleUp=btn(sTRow,"+",UDim2.new(0,22,0,24),UDim2.new(1,-22,0,0),T.btnAlt)

    local pPRow=mk("Frame",secPrev,{Size=UDim2.new(1,0,0,28),BackgroundTransparency=1,LayoutOrder=5})
    SaveUI.BtnPlaceZone=btn(pPRow,"Centro zona",UDim2.new(0.5,-3,1,0),UDim2.new(0,0,0,0),T.accent)
    SaveUI.BtnSaveSel=btn(pPRow,"Sel. Posicion",UDim2.new(0.5,-3,1,0),UDim2.new(0.5,3,0,0),T.btnAlt)
    SaveUI.btnBuildSaved=btn(secPrev,"CONSTRUIR GUARDADO",UDim2.new(1,0,0,32),nil,T.purple); SaveUI.btnBuildSaved.LayoutOrder=6
    SaveUI.prevStatus=mk("TextLabel",SaveUI.btnBuildSaved,{Size=UDim2.new(0,100,0,12),Position=UDim2.new(1,-104,1,-16),Text="",TextColor3=T.text,BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=9,TextXAlignment=Enum.TextXAlignment.Right})

    local selBox=mk("SelectionBox",SG,{Color3=T.accent,LineThickness=0.04})

    local function refPlaceBtns()
        SaveUI.BtnPlaceZone.BackgroundColor3=useCZ and T.accent or T.btnAlt; SaveUI.BtnPlaceZone.TextColor3=useCZ and T.bg or T.text
        SaveUI.BtnSaveSel.BackgroundColor3=(not useCZ)and T.accent or T.btnAlt; SaveUI.BtnSaveSel.TextColor3=(not useCZ)and T.bg or T.text
    end
    refPlaceBtns()

    SaveUI.BtnSavePrev.MouseButton1Click:Connect(function()
        savePrevOn=not savePrevOn
        SaveUI.BtnSavePrev.Text=savePrevOn and"Vista previa: On"or"Vista previa: Off"
        SaveUI.BtnSavePrev.BackgroundColor3=savePrevOn and T.accent or T.btnAlt
        SaveUI.BtnSavePrev.TextColor3=savePrevOn and T.bg or T.text
        renderSavePrev()
    end)

    local function refSaveTool()
        SaveUI.BtnSaveMove.BackgroundColor3=(saveToolMode=="move")   and T.btn or T.btnAlt
        SaveUI.BtnSaveRot.BackgroundColor3=(saveToolMode=="rotate") and T.btn or T.btnAlt
        updSaveHandles()
    end
    SaveUI.BtnSaveMove.MouseButton1Click:Connect(function() saveToolMode="move";   refSaveTool() end)
    SaveUI.BtnSaveRot.MouseButton1Click:Connect(function()  saveToolMode="rotate"; refSaveTool() end)

    SaveUI.btnScaleDown.MouseButton1Click:Connect(function() placeScale=math.max(0.1,placeScale-0.1); SaveUI.scaleLbl.Text=string.format("%.1fx",placeScale); renderSavePrev() end)
    SaveUI.btnScaleUp.MouseButton1Click:Connect(function()   placeScale=math.min(10,placeScale+0.1);  SaveUI.scaleLbl.Text=string.format("%.1fx",placeScale); renderSavePrev() end)

    SaveUI.BtnPlaceZone.MouseButton1Click:Connect(function()
        useCZ=true; refPlaceBtns()
        local z=closestZone(myRefPos()); if z then placePosV=z.Position+Vector3.new(0,z.Size.Y/2+1,0) elseif myBaseCF then placePosV=myBaseCF.Position end
        placeRot=CFrame.identity; renderSavePrev()
    end)

    local saveSel2=false
    SaveUI.BtnSaveSel.MouseButton1Click:Connect(function()
        if saveSel2 then return end; saveSel2=true
        SaveUI.BtnSaveSel.Text="Haz clic en una parte..."
        local rc,cc
        rc=RunService.RenderStepped:Connect(function() selBox.Adornee=Mouse.Target end)
        cc=Mouse.Button1Down:Connect(function()
            local t=Mouse.Target; if t and t:IsA("BasePart") and not t:IsDescendantOf(SG) then
                useCZ=false; refPlaceBtns(); placePosV=t.Position; placeRot=CFrame.identity
                rc:Disconnect(); cc:Disconnect(); selBox.Adornee=nil; saveSel2=false
                SaveUI.BtnSaveSel.Text="Sel. Posicion"; renderSavePrev()
            end
        end)
    end)

    -- Evitar renderizar si la pestaña no es visible
    LP:GetPropertyChangedSignal("Team"):Connect(function()
        task.wait(0.5)
        if not PageSave.Visible then return end
        local z=closestZone(myRefPos())
        if z then
            placePosV = z.Position + Vector3.new(0, z.Size.Y/2+1, 0)
            useCZ=true; refPlaceBtns(); renderSavePrev()
        end
    end)

    local renderSaveList
    renderSaveList = function()
        for _,c in ipairs(SaveUI.listCont:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end
        if #Saves==0 then
            SaveUI.listScroll.Size=UDim2.new(1,0,0,22)
            mk("TextLabel",SaveUI.listCont,{Size=UDim2.new(1,0,0,18),LayoutOrder=1,Text="(sin guardados)",TextColor3=T.sub,BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=10,TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Top})
            return
        end
        local newH=math.clamp(#Saves*34,34,102); SaveUI.listScroll.Size=UDim2.new(1,0,0,newH)
        for i=1,#Saves do
            local sv=Saves[i]; local isSel=(selSaveIdx==i)
            local row=mk("Frame",SaveUI.listCont,{Size=UDim2.new(1,0,0,30),BackgroundColor3=T.input,LayoutOrder=i}); corner(row,6)
            if isSel then local bar=mk("Frame",row,{Size=UDim2.new(0,4,1,-10),Position=UDim2.new(0,3,0,5),BackgroundColor3=T.accent,BorderSizePixel=0}); corner(bar,2) end
            local nblk=sv.data and sv.data.Block and #sv.data.Block or 0
            local nameCol=isSel and Color3.new(1,1,1) or T.text
            local nL=lbl(row,sv.name.." ("..nblk..")",UDim2.new(1,-96,1,0),UDim2.new(0,isSel and 14 or 8,0,0),nameCol)
            if isSel then nL.Font=Enum.Font.GothamBold end
            local useB=mk("TextButton",row,{Size=UDim2.new(0,48,0,22),Position=UDim2.new(1,-92,0.5,-11),Text="Usar",TextColor3=T.text,BackgroundColor3=T.purple,Font=Enum.Font.GothamBold,TextSize=9}); corner(useB,4)
            local delB=mk("TextButton",row,{Size=UDim2.new(0,40,0,22),Position=UDim2.new(1,-42,0.5,-11),Text="X",TextColor3=T.text,BackgroundColor3=T.danger,Font=Enum.Font.GothamBold,TextSize=11}); corner(delB,4)
            useB.MouseButton1Click:Connect(function()
                selSaveIdx=i; placeScale=1; placeRot=CFrame.identity; SaveUI.scaleLbl.Text="1.0x"
                local z=closestZone(myRefPos()); if z then placePosV=z.Position+Vector3.new(0,z.Size.Y/2+1,0) else placePosV=myRefPos() end
                renderSaveList(); renderSavePrev()
            end)
            delB.MouseButton1Click:Connect(function()
                local sv2=Saves[i]; if sv2 then local fp=sv2._path or(FS2.."/"..sv2.name..".json"); FSys.del(fp); delSaveOrd(sv2.name) end
                table.remove(Saves,i)
                if selSaveIdx==i then selSaveIdx=nil elseif selSaveIdx and selSaveIdx>i then selSaveIdx=selSaveIdx-1 end
                _G[GKEY]=Saves; renderSaveList(); renderSavePrev(); cCache={}
            end)
        end
    end

    SaveUI.btnSaveNow.MouseButton1Click:Connect(function()
        local base=myBaseCF or CFrame.new(myRefPos())
        local data,cnt=captureBuild(selPlayer or LP.Name, base)
        if not data then
            SaveUI.btnSaveNow.Text="Error"; SaveUI.btnSaveNow.BackgroundColor3=T.danger
            task.delay(1.5,function() if SaveUI.btnSaveNow and SaveUI.btnSaveNow.Parent then SaveUI.btnSaveNow.Text="Captura"; SaveUI.btnSaveNow.BackgroundColor3=T.build end end)
            return
        end
        local nm=SaveUI.nameInp.Text; nm=nm:gsub("%s+","_"); nm=nm:gsub("[^%w_%-]","")
        if nm=="" or nm=="_" then nm=autoName() end
        local used={}; for _,s in ipairs(Saves) do used[s.name]=true end
        if used[nm] then nm=nm.."_"..autoName() end
        local bd={name=nm,data=data}; local path=writeBF(nm,bd)
        if path then table.insert(Saves,1,{name=nm,data=data,_path=path}); addSaveOrd(nm)
        else table.insert(Saves,1,{name=nm,data=data,_path=FS2.."/"..nm..".json"}); addSaveOrd(nm) end
        renderSaveList(); SaveUI.nameInp.Text=""
        SaveUI.btnSaveNow.Text="✓"; SaveUI.btnSaveNow.BackgroundColor3=T.ok
        task.delay(1.2,function() if SaveUI.btnSaveNow and SaveUI.btnSaveNow.Parent then SaveUI.btnSaveNow.Text="Captura"; SaveUI.btnSaveNow.BackgroundColor3=T.build end end)
    end)

    local blockQueue2={}; local blockConn2=nil
    local function hookFolder2(folder) if blockConn2 then blockConn2:Disconnect(); blockConn2=nil end; blockQueue2={}; if folder then blockConn2=folder.ChildAdded:Connect(function(c) blockQueue2[#blockQueue2+1]=c end) end end
    local function popBlock2(timeout) local t0=tick(); while #blockQueue2==0 do if saveBuildState.cancel then return nil end; if tick()-t0>timeout then return nil end; task.wait() end; return table.remove(blockQueue2,1) end

    SaveUI.btnBuildSaved.MouseButton1Click:Connect(function()
        if saveBuildState.running then saveBuildState.cancel=true; SaveUI.prevStatus.Text="cancelando..."; SaveUI.prevStatus.TextColor3=T.danger; SaveUI.btnBuildSaved.Text="CANCELAR..."; return end
        if gbRunningRef.value then SaveUI.prevStatus.Text="ya hay una construcción en curso"; SaveUI.prevStatus.TextColor3=T.danger; return end
        local sv=selSaveIdx and Saves[selSaveIdx]; if not sv then SaveUI.prevStatus.Text="Selecciona un guardado"; SaveUI.prevStatus.TextColor3=T.danger; return end
        local bTool2=getTool("BuildingTool"); if not bTool2 then SaveUI.prevStatus.Text="Falta BuildingTool"; SaveUI.prevStatus.TextColor3=T.danger; return end
        local sTool2=getTool("ScalingTool"); local pTool2=getTool("PaintingTool")
        task.spawn(function()
            saveBuildState.running=true; saveBuildState.cancel=false; gbRunningRef.value=true
            SaveUI.btnBuildSaved.Text="CANCELAR"; SaveUI.btnBuildSaved.BackgroundColor3=T.danger; SaveUI.btnBuildSaved.Active=true
            local ok2,err=pcall(function()
                equipTool(bTool2); equipTool(sTool2); equipTool(pTool2)
                local bRF2=bTool2:FindFirstChild("RF"); local sRF2=sTool2 and sTool2:FindFirstChild("RF"); local pRF2=pTool2 and pTool2:FindFirstChild("RF")
                if not bRF2 then error("BuildingTool sin RF") end
                local pos=curPlacePos(); local delta=getSaveDelta(sv); local center=buildCenter(sv); local cAdj=delta*center
                local folder2=userFolder(LP.Name); hookFolder2(folder2)
                local blocks=sv.data.Block; local total=#blocks; local placed=0; 
                -- LÍMITE DE VELOCIDAD ULTRA MÁXIMA
                local WORKERS2=isSharing() and 15 or 50; local nextIdx2=1; local active2=WORKERS2; local ppairs={}
                local function pOB(pd)
                    local nm=pd.BlockName; local inv=dataFolder and dataFolder:FindFirstChild(nm); if not inv or inv.Value<=0 then return end
                    local rP=Vector3.new(pd.RelX,pd.RelY,pd.RelZ); local rR=CFrame.Angles(math.rad(pd.RotX or 0),math.rad(pd.RotY or 0),math.rad(pd.RotZ or 0))
                    local rPA=delta*rP; local rRA=(delta-delta.Position)*rR; local offset=(rPA-cAdj)*placeScale; local rotOff=placeRot*offset
                    local world=CFrame.new(pos+rotOff)*placeRot*rRA
                    if not folder2 or folder2.Parent==nil then folder2=userFolder(LP.Name); hookFolder2(folder2) end
                    local ret=bRF2:InvokeServer(nm,inv.Value,nil,world,true,world,false); local blk
                    if typeof(ret)=="Instance" and ret:IsA("BasePart") then blk=ret else blk=popBlock2(2) end
                    if blk then placed=placed+1; local sz=Vector3.new(pd.SizeX or 2,pd.SizeY or 2,pd.SizeZ or 2)*placeScale; if sRF2 then pcall(function() sRF2:InvokeServer(blk,sz,world) end) end; if pd.ColorR then ppairs[#ppairs+1]={blk,Color3.new(pd.ColorR,pd.ColorG,pd.ColorB)} end end
                end
                local function worker2() while true do if saveBuildState.cancel then break end; local i=nextIdx2; nextIdx2=nextIdx2+1; if i>total then break end; pOB(blocks[i]) end; active2=active2-1 end
                for _=1,WORKERS2 do task.spawn(worker2) end
                while active2>0 do SaveUI.prevStatus.Text=string.format("Construyendo %d/%d",placed,total); SaveUI.prevStatus.TextColor3=T.warn; task.wait(0.03) end
                if blockConn2 then blockConn2:Disconnect(); blockConn2=nil end
                if pRF2 and #ppairs>0 and not saveBuildState.cancel then SaveUI.prevStatus.Text=string.format("Pintando %d bloques...",#ppairs); SaveUI.prevStatus.TextColor3=T.warn; paintBatch(pRF2,ppairs) end
                if saveBuildState.cancel then SaveUI.prevStatus.Text="Cancelado ("..placed.." colocados)"; SaveUI.prevStatus.TextColor3=T.danger
                else SaveUI.prevStatus.Text="listo! "..placed.."/"..total.." colocados"; SaveUI.prevStatus.TextColor3=T.ok end
            end)
            if blockConn2 then blockConn2:Disconnect(); blockConn2=nil end
            if not ok2 then SaveUI.prevStatus.Text="error: "..tostring(err); SaveUI.prevStatus.TextColor3=T.danger end
            local hum2=LP.Character and LP.Character:FindFirstChild("Humanoid"); if hum2 then pcall(function() hum2:UnequipTools() end) end
            saveBuildState.running=false; saveBuildState.cancel=false; gbRunningRef.value=false
            SaveUI.btnBuildSaved.Text="CONSTRUIR GUARDADO"; SaveUI.btnBuildSaved.BackgroundColor3=T.purple; SaveUI.btnBuildSaved.Active=true
        end)
    end)

    local function updSelTC() if whoBtn and whoBtn.Parent then whoBtn.BackgroundColor3=getTeamColor(curUN) end end
    local function watchPTeam(p) p:GetPropertyChangedSignal("Team"):Connect(function() if p.Name==curUN then updSelTC() end; if whoVis then refreshWho() end end) end
    for _,p in ipairs(Players:GetPlayers()) do watchPTeam(p) end
    Players.PlayerAdded:Connect(function(p) watchPTeam(p); if whoVis then refreshWho() end end)
    Players.PlayerRemoving:Connect(function() task.defer(function() if whoVis then refreshWho() end end) end)

    return {
        page            = PageSave,
        renderSaveList  = renderSaveList,
        renderSavePrev  = renderSavePrev,
        updSaveHandles  = updSaveHandles,
        startSelTicker  = startSelTicker,
        reloadAndRender = function()
            -- Corre en un hilo para evitar congelamientos
            task.spawn(function()
                local rel=reloadSaves()
                for i = 1, #Saves do Saves[i] = nil end
                for i, v in ipairs(rel) do Saves[i] = v end
                renderSaveList()
                if selSaveIdx then renderSavePrev() else updSaveHandles() end
                startSelTicker()
            end)
        end,
        hidePreview     = function()
            for _,p in ipairs(savePool) do p.Transparency=1; p.Size=Vector3.new(0.05,0.05,0.05) end
            saveDummy.Position=Vector3.new(0,-9999,0); saveArcAdornee.Position=Vector3.new(0,-9999,0)
            SaveHandles.Visible=false; SaveArc.Visible=false
        end,
        myBaseCFSetter  = function(cf) myBaseCF=cf end,
        SaveHandles     = SaveHandles,
        SaveArc         = SaveArc,
    }
end

return BuildsModule
