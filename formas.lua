-- formas.lua
local FormasModule = {}

function FormasModule.init(ENV)
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
    local openCP      = ENV.openCP
    local RunService  = ENV.RunService
    local UserInputService = ENV.UserInputService
    local Camera      = ENV.Camera
    local Mouse       = ENV.Mouse
    local envF        = ENV.envF
    local prevF       = ENV.prevF
    local closestZone = ENV.closestZone
    local myRefPos    = ENV.myRefPos
    local ZONES       = ENV.ZONES
    local ZONE_DATA   = ENV.ZONE_DATA
    local LP          = ENV.LP
    local Players     = ENV.Players
    local getTool     = ENV.getTool
    local equipTool   = ENV.equipTool
    local userFolder  = ENV.userFolder
    local dataFolder  = ENV.dataFolder
    local isSharing   = ENV.isSharing
    local getMyLeader = ENV.getMyLeader
    local getShareSource = ENV.getShareSource
    local getActiveData  = ENV.getActiveData
    local getActiveTool  = ENV.getActiveTool
    local paintBatch  = ENV.paintBatch
    local ICON_MOVE   = ENV.ICON_MOVE
    local ICON_ROT    = ENV.ICON_ROT

    local PageBuild = mk("ScrollingFrame", Body, {
        Size = UDim2.new(1,0,1,0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = T.accent,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0,0,0,0),
        Visible = false
    })
    mk("UIListLayout", PageBuild, { Padding = UDim.new(0,6), SortOrder = Enum.SortOrder.LayoutOrder })
    pad(PageBuild, 10, 10, 10, 10)

    local selShape    = 1
    local centerPos   = nil
    local previewOn   = true
    local previewAlpha = 0.55
    local locked      = false
    local toolMode    = "move"
    local shapeRot    = CFrame.identity
    local hasRot      = false
    local capTopOn    = false
    local capBotOn    = false
    local capFillMode = "strips"
    local buildUseColor = false
    local selColor    = Color3.fromRGB(255,255,255)
    local selBlockName = "PlasticBlock"
    local gbRunningRef = ENV.gbRunning
    local buildState  = {running=false, cancel=false}

    local selBlockMat = Enum.Material.Plastic
    local selBlockCol = Color3.fromRGB(163,162,165)

    local needsRecenter = false

    local function readRealBlockVisual(blockName)
        local folder = userFolder and userFolder(LP.Name)
        if folder then
            for _, part in ipairs(folder:GetChildren()) do
                if part:IsA("BasePart") and part.Name == blockName then
                    return part.Material, part.Color
                end
            end
        end
        local ws = game:GetService("Workspace")
        local function searchRecursive(parent, depth)
            if depth > 4 then return nil, nil end
            for _, inst in ipairs(parent:GetChildren()) do
                if inst:IsA("BasePart") and inst.Name == blockName then
                    return inst.Material, inst.Color
                end
                local m, c = searchRecursive(inst, depth + 1)
                if m then return m, c end
            end
            return nil, nil
        end
        local mat, col = searchRecursive(ws, 0)
        if mat then return mat, col end
        local FALLBACK = {
            ["WoodBlock"]        = {mat=Enum.Material.Wood,        col=Color3.fromRGB(133, 94,  66)},
            ["PlasticBlock"]     = {mat=Enum.Material.Plastic,     col=Color3.fromRGB(163,162, 165)},
            ["MetalBlock"]       = {mat=Enum.Material.Metal,       col=Color3.fromRGB(155,155, 155)},
            ["GlassBlock"]       = {mat=Enum.Material.Glass,       col=Color3.fromRGB(160,230, 255)},
            ["IceBlock"]         = {mat=Enum.Material.Ice,         col=Color3.fromRGB(160,230, 255)},
            ["GrassBlock"]       = {mat=Enum.Material.Grass,       col=Color3.fromRGB( 75,151,  75)},
            ["CobblestoneBlock"] = {mat=Enum.Material.Cobblestone, col=Color3.fromRGB(110,110, 110)},
            ["ConcreteBlock"]    = {mat=Enum.Material.Concrete,    col=Color3.fromRGB(140,140, 140)},
            ["NeonBlock"]        = {mat=Enum.Material.Neon,        col=Color3.fromRGB(200,200, 200)},
        }
        local fb = FALLBACK[blockName] or {mat=Enum.Material.Plastic, col=Color3.fromRGB(163,162,165)}
        return fb.mat, fb.col
    end

    local generateShape, SHAPES
    do
        local function circPts(n) local p={}; for i=0,n-1 do local a=(i/n)*math.pi*2; p[#p+1]=Vector2.new(math.cos(a),math.sin(a)) end; return p end
        local function polyPts(sides,off) local p={}; for k=0,sides-1 do local a=off+k*(2*math.pi/sides); p[#p+1]=Vector2.new(math.cos(a),math.sin(a)) end; return p end
        local function heartPts() local p={}; for k=0,127 do local t=(k/128)*2*math.pi; p[#p+1]=Vector2.new(16*math.sin(t)^3/17,-(13*math.cos(t)-5*math.cos(2*t)-2*math.cos(3*t)-math.cos(4*t))/17) end; return p end
        local SQ={Vector2.new(1,1),Vector2.new(-1,1),Vector2.new(-1,-1),Vector2.new(1,-1)}
        local function perimOf(u,r) local n=#u; local per=0; for i=1,n do local a=u[i]*r; local b=u[(i%n)+1]*r; per=per+(b-a).Magnitude end; return per end
        local function buildSampler(u,closed,r)
            local sc={}; for _,p in ipairs(u) do sc[#sc+1]=p*r end
            local n=#sc; local last=closed and n or n-1
            local aL={0}; for i=1,last do local a=sc[i]; local b=sc[(i%n)+1]; aL[i+1]=aL[i]+math.sqrt((b.X-a.X)^2+(b.Y-a.Y)^2) end
            local tot=aL[last+1]; if tot<=0 then return nil,0 end
            local function eval(t)
                local tgt=math.clamp(t,0,1)*tot; local lo,hi=1,last
                while lo<hi do local m=math.floor((lo+hi)/2); if aL[m+1]<tgt then lo=m+1 else hi=m end end
                local seg=lo; local a=sc[seg]; local b=sc[(seg%n)+1]
                local segL=aL[seg+1]-aL[seg]; local u2=segL>0 and(tgt-aL[seg])/segL or 0; u2=math.clamp(u2,0,1)
                local pos=Vector2.new(a.X+(b.X-a.X)*u2, a.Y+(b.Y-a.Y)*u2)
                local dir=Vector2.new(b.X-a.X, b.Y-a.Y); if dir.Magnitude<0.0001 then dir=Vector2.new(1,0) end
                return pos, dir.Unit
            end
            return eval, tot
        end
        local function placeRing(plan,u,closed,cx,cy,cz,r,bH,th,count)
            local ev,per=buildSampler(u,closed,r); if not ev then return end
            local bL=(per/math.max(1,count))*1.06
            for k=0,count-1 do
                local pos,dir=ev((k+0.5)/count)
                local wm=Vector3.new(cx+pos.X,cy,cz+pos.Y); local wd=Vector3.new(dir.X,0,dir.Y)
                plan[#plan+1]={cframe=CFrame.lookAt(wm,wm+wd), size=Vector3.new(th,bH,bL)}
            end
        end
        local function polyBounds(u,r)
            local pts={}; local minX,maxX,minZ,maxZ=1e9,-1e9,1e9,-1e9
            for _,p in ipairs(u) do local x,z=p.X*r,p.Y*r; pts[#pts+1]={x,z}; if x<minX then minX=x end; if x>maxX then maxX=x end; if z<minZ then minZ=z end; if z>maxZ then maxZ=z end end
            return pts,minX,maxX,minZ,maxZ
        end
        local function makeInside(pts)
            local n=#pts
            return function(px,pz) local c=false; local j=n; for i=1,n do local xi,zi=pts[i][1],pts[i][2]; local xj,zj=pts[j][1],pts[j][2]; if((zi>pz)~=(zj>pz))and(px<(xj-xi)*(pz-zi)/((zj-zi)+1e-12)+xi)then c=not c end; j=i end; return c end
        end
        local function fillGrid(plan,u,cx,cy,cz,r,th,step)
            local pts,minX,maxX,minZ,maxZ=polyBounds(u,r); local ins=makeInside(pts)
            local gx=minX+step*0.5; while gx<=maxX+1e-6 do local gz=minZ+step*0.5; while gz<=maxZ+1e-6 do if ins(gx,gz) then plan[#plan+1]={cframe=CFrame.new(cx+gx,cy,cz+gz),size=Vector3.new(step,th,step)} end; gz=gz+step end; gx=gx+step end
        end
        local function fillStrips(plan,u,cx,cy,cz,r,th,step)
            local pts,minX,maxX,minZ,maxZ=polyBounds(u,r); local ins=makeInside(pts)
            local sample=math.max(step*0.30,(maxX-minX)/240)
            local gz=minZ+step*0.5
            while gz<=maxZ+1e-6 do
                local spanStart=nil; local prevIns=false; local x=minX
                local function flush(x0,x1) local w=x1-x0; if w>0 then plan[#plan+1]={cframe=CFrame.new(cx+(x0+x1)/2,cy,cz+gz),size=Vector3.new(w+sample,th,step*1.02)} end end
                while x<=maxX+1e-6 do local i2=ins(x,gz); if i2 and not prevIns then spanStart=x elseif(not i2)and prevIns then flush(spanStart,x-sample); spanStart=nil end; prevIns=i2; x=x+sample end
                if prevIns and spanStart then flush(spanStart,maxX) end
                gz=gz+step
            end
        end
        local function fillCap(plan,u,cx,cy,cz,r,th,step)
            if capFillMode=="grid" then fillGrid(plan,u,cx,cy,cz,r,th,step) else fillStrips(plan,u,cx,cy,cz,r,th,step) end
        end
        local function buildExtruded(plan,u,cx,cy,cz,r,h,th,count,cT,cB)
            local per=perimOf(u,r); local seg=per/math.max(1,count)
            placeRing(plan,u,true,cx,cy,cz,r,h,th,count)
            if cT then fillCap(plan,u,cx,cy+h/2-th/2,cz,r,th,seg) end
            if cB then fillCap(plan,u,cx,cy-h/2+th/2,cz,r,th,seg) end
        end
        local function buildCube(plan,cx,cy,cz,r,th,count,cT,cB)
            local pF=math.max(1,math.floor(count/6+0.5)); local gN=math.max(1,math.round(math.sqrt(pF))); local half=r; local step=(2*half)/gN; local bs=step*1.02
            local function face(ax,v) for r2=0,gN-1 do for c2=0,gN-1 do local u2=-half+step*c2+step/2; local v2=-half+step*r2+step/2; if ax=="y" then plan[#plan+1]={cframe=CFrame.new(cx+u2,cy+v,cz+v2),size=Vector3.new(bs,th,bs)} elseif ax=="x" then plan[#plan+1]={cframe=CFrame.new(cx+v,cy+u2,cz+v2),size=Vector3.new(th,bs,bs)} else plan[#plan+1]={cframe=CFrame.new(cx+u2,cy+v2,cz+v),size=Vector3.new(bs,bs,th)} end end end end
            face("x",half); face("x",-half); face("z",half); face("z",-half)
            if cT then face("y",half) end
            if cB then face("y",-half) end
        end
        local function buildSphere(plan,cx,cy,cz,r,th,count)
            count=math.max(8,count); local L=math.max(3,math.round(math.sqrt(count/2))); local M=math.max(6,L*2)
            local lS=(2*math.pi)/M; local loS=math.pi/L; local sL=r*lS*1.08; local sW=r*loS*1.08
            local center=CFrame.new(cx,cy,cz)
            for li=0,L-1 do local phi=loS*li; local rR=CFrame.Angles(0,phi,0); for ai=0,M-1 do local a=lS*ai; local lCF=CFrame.new(0,r*math.cos(a),r*math.sin(a))*CFrame.Angles(a,0,0); plan[#plan+1]={cframe=center*rR*lCF, size=Vector3.new(sW,th,sL)} end end
        end
        local function addHalfEllipsoid(plan,cx,cy,cz,r,aL,th,count,top)
            count=math.max(8,count); local L=math.max(3,math.round(math.sqrt(count/2))); local M=math.max(6,L*2)
            local lS=(2*math.pi)/M; local loS=math.pi/L; local sW=r*loS*1.10; local ys=aL/r
            local center=CFrame.new(cx,cy,cz)
            local function cP(ang) return r*math.cos(ang)*ys, r*math.sin(ang) end
            for li=0,L-1 do local phi=loS*li; local rR=CFrame.Angles(0,phi,0)
                for ai=0,M-1 do local a=lS*ai; local cosa=math.cos(a); local keep=top and(cosa>=-1e-6)or((not top)and(cosa<=1e-6))
                    if keep then local yy=r*cosa*ys; local y0,z0=cP(a-lS/2); local y1,z1=cP(a+lS/2); local dy,dz=y1-y0,z1-z0; local sLen=math.sqrt(dy*dy+dz*dz); if sLen<1e-6 then dy,dz,sLen=0,1,1 end; local nx,ny,nz=0,dz,-dy; local nm=math.sqrt(ny*ny+nz*nz); if nm<1e-9 then nm=1 end; local lCF=CFrame.fromMatrix(Vector3.new(0,yy,r*math.sin(a)),Vector3.new(1,0,0),Vector3.new(nx,ny/nm,nz/nm),Vector3.new(0,dy/sLen,dz/sLen)); plan[#plan+1]={cframe=center*rR*lCF, size=Vector3.new(sW,th,sLen*1.10)} end
                end
            end
        end
        local function buildPyramid(plan,cx,cy,cz,r,h,th,count,p01,cB)
            local hs=r; local expo=0.5+p01*2.5; local layers=math.clamp(math.floor(count/4+0.5),3,160); local lH=h/layers
            local faces={{dir=Vector3.new(1,0,0),side=Vector3.new(0,0,1)},{dir=Vector3.new(-1,0,0),side=Vector3.new(0,0,1)},{dir=Vector3.new(0,0,1),side=Vector3.new(1,0,0)},{dir=Vector3.new(0,0,-1),side=Vector3.new(1,0,0)}}
            local function prof(t) return hs*((1-t)^expo) end
            for _,f in ipairs(faces) do for i=0,layers-1 do local t0=i/layers; local t1=(i+1)/layers; local tc=(i+0.5)/layers; local dc=prof(tc); local yc=(cy-h/2)+tc*h; local pBot=f.dir*prof(t0)+Vector3.new(0,(cy-h/2)+t0*h,0); local pTop=f.dir*prof(t1)+Vector3.new(0,(cy-h/2)+t1*h,0); local u=(pTop-pBot); local sL=u.Magnitude; if sL<1e-4 then u=Vector3.new(0,1,0); sL=lH else u=u.Unit end; local v=f.side; local n2=u:Cross(v); if n2:Dot(f.dir)<0 then v=-v; n2=u:Cross(v) end; n2=n2.Unit; v=v.Unit; local width=2*dc; if width<1e-3 then width=sL*0.5 end; plan[#plan+1]={cframe=CFrame.fromMatrix(Vector3.new(cx,0,cz)+f.dir*dc+Vector3.new(0,yc,0),v,n2), size=Vector3.new(width*1.04,th,sL*1.05)} end end
            if cB then fillCap(plan,SQ,cx,cy-h/2+th/2,cz,hs,th,(2*hs)/math.max(4,layers)) end
        end
        local function buildCapsule(plan,cx,cy,cz,r,h,th,count,p01)
            local circle=circPts(96); local capL=r*(1+p01*1.5); local bodyH=math.max(h,0)
            if bodyH>0.01 then placeRing(plan,circle,true,cx,cy,cz,r,bodyH,th,count) end
            addHalfEllipsoid(plan,cx,cy+bodyH/2,cz,r,capL,th,count,true)
            addHalfEllipsoid(plan,cx,cy-bodyH/2,cz,r,capL,th,count,false)
        end
        SHAPES = {
            {label="Circulo",  icon="circle",  kind="extrude",  pts=function() return circPts(96) end,         caps="both",   fillable=true,  useHeight=true,  useCount=true, usePoint=false},
            {label="Cuadrado", icon="square",  kind="extrude",  pts=function() return polyPts(4,math.pi/4) end, caps="both",  fillable=true,  useHeight=true,  useCount=true, usePoint=false},
            {label="Corazon",  icon="heart",   kind="extrude",  pts=heartPts,                                   caps="both",  fillable=true,  useHeight=true,  useCount=true, usePoint=false},
            {label="Cubo",     icon="cube",    kind="cube3d",   caps="both",   fillable=false, useHeight=false, useCount=true, usePoint=false},
            {label="Esfera",   icon="sphere",  kind="sphere3d", caps=false,    fillable=false, useHeight=false, useCount=true, usePoint=false},
            -- Pirámide: fillable=false para que NO aparezca la fila Tiras/Bloques
            {label="Piramide", icon="pyramid", kind="pyramid",  caps="bottom", fillable=false, useHeight=true,  useCount=true, usePoint=true, pointy=true},
            {label="Capsula",  icon="capsule", kind="capsule",  caps=false,    fillable=false, useHeight=true,  useCount=true, usePoint=true, pointy=true},
        }
        generateShape = function(def, cp, P)
            local plan={}; if not cp then return plan end
            local cx,cy,cz=cp.X,cp.Y,cp.Z; local k=def.kind
            if k=="extrude"    then buildExtruded(plan,def.pts(),cx,cy,cz,P.radius,P.height,P.thick,P.count,P.capTop,P.capBottom)
            elseif k=="cube3d" then buildCube(plan,cx,cy,cz,P.radius,P.thick,P.count,P.capTop,P.capBottom)
            elseif k=="sphere3d" then buildSphere(plan,cx,cy,cz,P.radius,P.thick,P.count)
            elseif k=="pyramid" then buildPyramid(plan,cx,cy,cz,P.radius,P.height,P.thick,P.count,P.point,P.capBottom)
            elseif k=="capsule" then buildCapsule(plan,cx,cy,cz,P.radius,P.height,P.thick,P.count,P.point)
            end
            if hasRot then local pivot=CFrame.new(cx,cy,cz); local rot=pivot*shapeRot*pivot:Inverse(); for _,s in ipairs(plan) do s.cframe=rot*s.cframe end end
            return plan
        end
    end

    local drawIcon
    do
        local function dLine(par,x1,y1,x2,y2,col)
            local dx,dy=x2-x1,y2-y1; local len=math.sqrt(dx*dx+dy*dy); if len<1 then return end
            mk("Frame",par,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromOffset((x1+x2)/2,(y1+y2)/2),Size=UDim2.fromOffset(len,2),BorderSizePixel=0,BackgroundColor3=col,Rotation=math.deg(math.atan2(dy,dx))})
        end
        drawIcon = function(container, def, col)
            for _,c in ipairs(container:GetChildren()) do if not c:IsA("UICorner") and not c:IsA("UIStroke") then c:Destroy() end end
            local bsz=container.AbsoluteSize.X; if bsz<=0 then bsz=30 end
            local R=(bsz/2)-3; local cx2,cy2=bsz/2,bsz/2; local ic=def.icon
            if ic=="circle" then local ring=mk("Frame",container,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(R*2,R*2),BackgroundTransparency=1}); corner(ring,999); mk("UIStroke",ring,{Color=col,Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
            elseif ic=="square" then local s=R*0.85; dLine(container,cx2-s,cy2-s,cx2+s,cy2-s,col); dLine(container,cx2+s,cy2-s,cx2+s,cy2+s,col); dLine(container,cx2+s,cy2+s,cx2-s,cy2+s,col); dLine(container,cx2-s,cy2+s,cx2-s,cy2-s,col)
            elseif ic=="sphere" then local ring=mk("Frame",container,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(R*2,R*2),BackgroundTransparency=1}); corner(ring,999); mk("UIStroke",ring,{Color=col,Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border}); dLine(container,cx2-R,cy2,cx2+R,cy2,col)
            elseif ic=="cube" then local s=R*0.6; local o=R*0.5; local fr={{-s,-s},{s,-s},{s,s},{-s,s}}; local bk={}; for i,c2 in ipairs(fr) do bk[i]={c2[1]+o,c2[2]-o} end; for i=1,4 do local a,b2=fr[i],fr[(i%4)+1]; local a2,b3=bk[i],bk[(i%4)+1]; dLine(container,cx2+a[1],cy2+a[2],cx2+b2[1],cy2+b2[2],col); dLine(container,cx2+a2[1],cy2+a2[2],cx2+b3[1],cy2+b3[2],col); dLine(container,cx2+a[1],cy2+a[2],cx2+a2[1],cy2+a2[2],col) end
            elseif ic=="pyramid" then local tx,ty=cx2,cy2-R; local blx,bly=cx2-R,cy2+R*0.8; local brx,bry=cx2+R,cy2+R*0.8; dLine(container,tx,ty,blx,bly,col); dLine(container,tx,ty,brx,bry,col); dLine(container,blx,bly,brx,bry,col); dLine(container,tx,ty,cx2+R*0.35,bry,col)
            elseif ic=="capsule" then local st=mk("Frame",container,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(R*1.2,R*2),BackgroundTransparency=1}); corner(st,999); mk("UIStroke",st,{Color=col,Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
            elseif ic=="heart" then local scale=R*0.82; local pts={}; local N=32; for k2=0,N-1 do local t=(k2/N)*2*math.pi; local px=16*math.sin(t)^3; local py=-(13*math.cos(t)-5*math.cos(2*t)-2*math.cos(3*t)-math.cos(4*t)); pts[k2+1]={cx2+px*scale/17, cy2+py*scale/17} end; for i=1,N do local a2=pts[i]; local b2=pts[(i%N)+1]; dLine(container,a2[1],a2[2],b2[1],b2[2],col) end
            end
        end
    end

    local BInput = {}
    local PARAM_MINS = {radius=0.01,height=0.01,thick=0.01,count=4,point=0}
    local readParams = function()
        return {
            radius   = math.max(PARAM_MINS.radius,  tonumber(BInput.bRadius and BInput.bRadius.Text) or 20),
            height   = math.max(PARAM_MINS.height,  tonumber(BInput.bSizeY  and BInput.bSizeY.Text)  or 8),
            thick    = math.max(PARAM_MINS.thick,   tonumber(BInput.bThick  and BInput.bThick.Text)  or 1),
            count    = math.max(PARAM_MINS.count,   math.floor(tonumber(BInput.bSteps and BInput.bSteps.Text) or 120)),
            point    = math.clamp(tonumber(BInput.bPunta and BInput.bPunta.Text) or 0, 0, 1),
            capTop   = capTopOn,
            capBottom = capBotOn,
        }
    end

    local cDummy = mk("Part", envF, {Size=Vector3.new(4,4,4),Transparency=1,Color=T.accent,Anchored=true,CanCollide=false,CanQuery=false,Material=Enum.Material.Plastic,Position=Vector3.new(0,-9999,0)})

    local rowBuild = {}
    local function bRow(h, visFn)
        local f = mk("Frame", PageBuild, {Size=UDim2.new(1,0,0,h),BackgroundTransparency=1,LayoutOrder=#rowBuild+1})
        rowBuild[#rowBuild+1] = {frame=f, vis=visFn}
        return f
    end
    local function refreshBuildRows()
        for _,r in ipairs(rowBuild) do r.frame.Visible = (r.vis==nil) or r.vis() end
    end

    local function bindHold(b, fn)
        local h=false
        local function go() if h then return end; h=true; fn(); task.spawn(function() local d=0.35; task.wait(d); while h do fn(); task.wait(d); d=math.max(0.03,d*0.75) end end) end
        local function stop() h=false end
        b.MouseButton1Down:Connect(go); b.MouseButton1Up:Connect(stop); b.MouseLeave:Connect(stop)
    end

    local function cleanNum(t)
        local out={}; local dotUsed=false
        for i=1,#t do local c=t:sub(i,i); if c:match("%d") then out[#out+1]=c elseif c=="-" and i==1 and #out==0 then out[#out+1]=c elseif c=="." and not dotUsed then out[#out+1]=c; dotUsed=true end end
        return table.concat(out)
    end

    local prevDirty = false
    local function markPreview() prevDirty=true end

    local function mkNumRow(row, label, default, step, minVal)
        lbl(row, label, UDim2.new(0,72,1,0), UDim2.new(0,0,0,0), T.sub)
        local bl = btn(row, "-", UDim2.new(0,24,0,24), UDim2.new(0,76,0,0), T.btnAlt)
        local bx = box(row, UDim2.new(1,-132,0,24), UDim2.new(0,104,0,0), default)
        bx.TextXAlignment = Enum.TextXAlignment.Center
        local br = btn(row, "+", UDim2.new(0,24,0,24), UDim2.new(1,-24,0,0), T.btnAlt)
        local decimal=(step<1) or (minVal~=nil and minVal<1)
        local function fmt(n) if minVal then n=math.max(minVal,n) end; if decimal then if n==math.floor(n) then return tostring(math.floor(n)) else return string.format("%.2f",n) end else return tostring(math.floor(n+0.5)) end end
        local function smartStep(cur,dir)
            if minVal~=nil and dir<0 and cur<=minVal+0.0001 then return minVal end
            if decimal then local curIsInt=(math.abs(cur-math.floor(cur+0.5))<0.0001); if curIsInt then local iv=math.floor(cur+0.5); if dir>0 then return iv>=1 and(iv+1) or math.floor((cur+0.1)*100+0.5)/100 else if iv>1 then return math.max(minVal or -math.huge,iv-1) elseif iv==1 then return math.max(minVal or -math.huge,0.9) else local nx=cur<=0.1+0.0001 and math.floor((cur-0.01)*1000+0.5)/1000 or math.floor((cur-0.1)*100+0.5)/100; return minVal and math.max(minVal,nx) or nx end end else if dir>0 then if cur<0.1-0.0001 then return math.floor((cur+0.01)*1000+0.5)/1000 else local ni=math.floor(cur)+1; return(ni-cur<=0.1+0.0001) and ni or math.floor((cur+0.1)*100+0.5)/100 end else local nx=cur<=0.1+0.0001 and math.floor((cur-0.01)*1000+0.5)/1000 or math.floor((cur-0.1)*100+0.5)/100; return minVal and math.max(minVal,nx) or nx end end else local nx=math.floor(cur+dir*step+0.5); return minVal and math.max(minVal,nx) or nx end
        end
        local guard=false
        bx:GetPropertyChangedSignal("Text"):Connect(function() if guard then return end; local c=cleanNum(bx.Text); if c~=bx.Text then guard=true; bx.Text=c; guard=false end; markPreview() end)
        bx.FocusLost:Connect(function() local v=tonumber(bx.Text); if not v or bx.Text=="" then local fb=minVal or tonumber(default) or 0; guard=true; bx.Text=fmt(fb); guard=false; markPreview() elseif minVal and v<minVal then guard=true; bx.Text=fmt(minVal); guard=false; markPreview() end end)
        bindHold(bl, function() local cur=tonumber(bx.Text); if not cur then cur=minVal or 0 end; bx.Text=fmt(smartStep(cur,-1)); markPreview() end)
        bindHold(br, function() local cur=tonumber(bx.Text); if not cur then cur=minVal or 0 end; bx.Text=fmt(smartStep(cur,1)); markPreview() end)
        return bx
    end

    local function stepVal(bx) local v=tonumber(bx and bx.Text); if not v or v<0 then v=0 end; return v end
    local function mkStepBox(parent, size, pos, default)
        local bx=box(parent,size,pos,default); bx.TextXAlignment=Enum.TextXAlignment.Center
        local guard=false
        bx:GetPropertyChangedSignal("Text"):Connect(function() if guard then return end; local c=cleanNum(bx.Text); if c~=bx.Text then guard=true; bx.Text=c; guard=false end end)
        bx.FocusLost:Connect(function() local v=tonumber(bx.Text); if not v or v<0 then guard=true; bx.Text="0"; guard=false end end)
        return bx
    end

    local shapeBtns  = {}
    local shapeIcons = {}
    local onShapeChange
    local function refreshShapes()
        for i,b in ipairs(shapeBtns) do
            local sel=(i==selShape); b.BackgroundColor3=sel and T.btn or T.btnAlt
            local st=b:FindFirstChildOfClass("UIStroke"); if st then st.Enabled=sel end
            if shapeIcons[i] then task.defer(function() drawIcon(shapeIcons[i],SHAPES[i],sel and T.text or T.accent) end) end
        end
    end

    -- ══════════════════════════════════════════════
    -- UI ORDEN 1: Grid de formas
    -- ══════════════════════════════════════════════
    do
        local rGrid = bRow(90)
        mk("UIGridLayout", rGrid, {CellSize=UDim2.new(0,38,0,38),CellPadding=UDim2.new(0,6,0,6),SortOrder=Enum.SortOrder.LayoutOrder})
        rGrid.BackgroundTransparency=1
        for i,def in ipairs(SHAPES) do
            if type(def)=="table" and def.label then
                local b=mk("TextButton",rGrid,{Text="",BackgroundColor3=T.btnAlt,TextColor3=T.text,BorderSizePixel=0,LayoutOrder=i,AutoButtonColor=false}); corner(b,8)
                local st=stroke(b,T.accent,2); st.Enabled=false
                local ic=mk("Frame",b,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(0,26,0,26),BackgroundTransparency=1})
                shapeBtns[i]=b; shapeIcons[i]=ic
                b.MouseButton1Click:Connect(function() selShape=i; if onShapeChange then onShapeChange() end end)
                task.defer(function() task.wait(0.1); drawIcon(ic,def,T.accent) end)
            end
        end
    end

    -- ══════════════════════════════════════════════
    -- UI ORDEN 2: Parámetros numéricos
    -- ══════════════════════════════════════════════
    do
        local rRad=bRow(24); BInput.bRadius=mkNumRow(rRad,"Radio","20",1,0.01)
        local rCnt=bRow(24,function() local d=SHAPES[selShape]; return d and d.useCount~=false end); BInput.bSteps=mkNumRow(rCnt,"Parts","120",4,4)
        local rHgt=bRow(24,function() local d=SHAPES[selShape]; return d and d.useHeight==true end); BInput.bSizeY=mkNumRow(rHgt,"Altura","8",1,0.01)
        local rThk=bRow(24); BInput.bThick=mkNumRow(rThk,"Grosor","1",0.1,0.01)
        local rPnt=bRow(24,function() local d=SHAPES[selShape]; return d and d.usePoint==true end); BInput.bPunta=mkNumRow(rPnt,"Punta","0",0.1,0)
    end

    -- ══════════════════════════════════════════════
    -- UI ORDEN 3: Tapas — SIMÉTRICAS, sin label "Tapas" para más espacio
    -- ══════════════════════════════════════════════
    local capBtnTop, capBtnBot
    local function refreshCaps()
        local def=SHAPES[selShape]
        if def and def.caps=="bottom" then
            -- Solo "Tapa base": centrado en toda la fila
            capBtnTop.Visible=false
            capBtnBot.Visible=true
            capBtnBot.Size        = UDim2.new(1, 0, 0, 22)
            capBtnBot.AnchorPoint = Vector2.new(0.5, 0.5)
            capBtnBot.Position    = UDim2.new(0.5, 0, 0.5, 0)
            capBtnBot.Text        = "▼ Tapa base"
        else
            -- Dos tapas: cada una ocupa ~50% con pequeño gap entre ellas
            local gap = 3
            capBtnTop.Visible=true
            capBtnBot.Visible=true
            capBtnTop.Text        = "▲ Tapa Sup"
            capBtnTop.Size        = UDim2.new(0.5, -gap, 0, 22)
            capBtnTop.AnchorPoint = Vector2.new(0, 0.5)
            capBtnTop.Position    = UDim2.new(0, 0, 0.5, 0)
            capBtnBot.Text        = "▼ Tapa Inf"
            capBtnBot.Size        = UDim2.new(0.5, -gap, 0, 22)
            capBtnBot.AnchorPoint = Vector2.new(1, 0.5)
            capBtnBot.Position    = UDim2.new(1, 0, 0.5, 0)
        end
        capBtnTop.BackgroundColor3=capTopOn and T.build or T.btnAlt
        capBtnBot.BackgroundColor3=capBotOn and T.build or T.btnAlt
    end
    do
        local rCap=bRow(26, function() local d=SHAPES[selShape]; return d and d.caps~=false end)
        capBtnTop=btn(rCap,"▲ Tapa Sup",UDim2.new(0.5,-3,0,22),nil,T.btnAlt)
        capBtnTop.AnchorPoint=Vector2.new(0,0.5); capBtnTop.Position=UDim2.new(0,0,0.5,0)
        capBtnBot=btn(rCap,"▼ Tapa Inf",UDim2.new(0.5,-3,0,22),nil,T.btnAlt)
        capBtnBot.AnchorPoint=Vector2.new(1,0.5); capBtnBot.Position=UDim2.new(1,0,0.5,0)
        capBtnTop.MouseButton1Click:Connect(function() capTopOn=not capTopOn; refreshCaps(); markPreview() end)
        capBtnBot.MouseButton1Click:Connect(function() capBotOn=not capBotOn; refreshCaps(); markPreview() end)
    end

    -- ══════════════════════════════════════════════
    -- UI ORDEN 4: Relleno — solo formas fillable=true con tapa activa
    -- (Pirámide tiene fillable=false ahora → no aparece aquí)
    -- ══════════════════════════════════════════════
    local fillStripBtn, fillGridBtn
    local function refreshFill()
        if fillStripBtn then fillStripBtn.BackgroundColor3=(capFillMode=="strips") and T.build or T.btnAlt end
        if fillGridBtn  then fillGridBtn.BackgroundColor3=(capFillMode=="grid")   and T.build or T.btnAlt end
    end
    do
        local rFill=bRow(24,function()
            local d=SHAPES[selShape]
            return d and d.fillable==true and (capTopOn or capBotOn)
        end)
        lbl(rFill,"Relleno",UDim2.new(0,50,1,0),nil,T.sub)
        fillStripBtn=btn(rFill,"Tiras",UDim2.new(0,80,0,24),UDim2.new(0,52,0,0),T.build)
        fillGridBtn=btn(rFill,"Bloques",UDim2.new(0,80,0,24),UDim2.new(0,138,0,0),T.btnAlt)
        fillStripBtn.MouseButton1Click:Connect(function() capFillMode="strips"; refreshFill(); markPreview() end)
        fillGridBtn.MouseButton1Click:Connect(function() capFillMode="grid"; refreshFill(); markPreview() end)
    end

    -- ══════════════════════════════════════════════
    -- UI ORDEN 5: COLOR & MATERIAL
    -- ══════════════════════════════════════════════
    local selBlockNameRef = {value="PlasticBlock"}
    local matPickOv, matPickBtn
    local mLabelRef
    local mIconRef

    local function updMatBtn(nm, iconId)
        selBlockNameRef.value = nm
        selBlockName = nm
        if mLabelRef then mLabelRef.Text = nm end
        if mIconRef  then mIconRef.Image  = iconId or "rbxassetid://12328114032" end
        task.spawn(function()
            local mat, col = readRealBlockVisual(nm)
            selBlockMat = mat
            selBlockCol = col
            markPreview()
        end)
    end

    do
        local rColorMat = bRow(28)

        local colBtnInd = mk("Frame", rColorMat, {
            Size = UDim2.new(0, 22, 0, 22),
            Position = UDim2.new(0, 4, 0.5, -11),
            BackgroundColor3 = Color3.new(1,1,1),
            BorderSizePixel = 0
        })
        corner(colBtnInd, 11); stroke(colBtnInd, T.text, 1.5)

        local bOP = btn(rColorMat, "Elegir color", UDim2.new(0, 80, 0, 24), UDim2.new(0, 30, 0.5, -12), T.btn)

        local bTC = btn(rColorMat, "ON", UDim2.new(0, 36, 0, 24), UDim2.new(0, 114, 0.5, -12), T.btnAlt)
        local function refCB()
            bTC.BackgroundColor3 = buildUseColor and T.build or T.btnAlt
            bTC.Text = buildUseColor and "ON" or "OFF"
        end
        refCB()
        bTC.MouseButton1Click:Connect(function()
            buildUseColor = not buildUseColor
            refCB()
            markPreview()
        end)
        bOP.MouseButton1Click:Connect(function()
            openCP(selColor, function(col)
                selColor = col
                colBtnInd.BackgroundColor3 = col
                buildUseColor = true
                refCB()
                markPreview()
            end,
            function(col)
                selColor = col
                colBtnInd.BackgroundColor3 = col
                if buildUseColor then markPreview() end
            end)
        end)

        matPickBtn = mk("TextButton", rColorMat, {
            Size = UDim2.new(1, -160, 0, 24),
            Position = UDim2.new(0, 156, 0.5, -12),
            BackgroundColor3 = T.input,
            BorderSizePixel = 0,
            Font = Enum.Font.GothamSemibold,
            TextSize = 10,
            Text = "",
            TextColor3 = T.text,
            TextXAlignment = Enum.TextXAlignment.Left
        })
        corner(matPickBtn, 6)

        mIconRef = mk("ImageLabel", matPickBtn, {
            Size = UDim2.new(0, 20, 0, 20),
            Position = UDim2.new(0, 4, 0.5, -10),
            BackgroundTransparency = 1,
            BorderSizePixel = 0
        })
        mLabelRef = mk("TextLabel", matPickBtn, {
            Size = UDim2.new(1, -32, 1, 0),
            Position = UDim2.new(0, 28, 0, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamSemibold,
            TextSize = 10,
            TextColor3 = T.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = selBlockNameRef.value
        })

        -- Overlay bloque: fondo oscuro cierra al tocar afuera
        matPickOv = mk("Frame", ENV.Win, {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0.35,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 60
        })
        -- Botón invisible de fondo para cerrar
        local matPickBg = mk("TextButton", matPickOv, {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            ZIndex = 60,
            AutoButtonColor = false
        })
        matPickBg.MouseButton1Click:Connect(function() matPickOv.Visible = false end)

        local pBox = mk("Frame", matPickOv, {
            Size = UDim2.new(1, -20, 0.85, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            BackgroundColor3 = T.panel,
            BorderSizePixel = 0,
            ZIndex = 61
        })
        corner(pBox, 10)

        mk("TextLabel", pBox, {
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundTransparency = 1,
            Text = "ELEGIR BLOQUE",
            TextColor3 = T.text,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 62
        })

        local pScroll = mk("ScrollingFrame", pBox, {
            Size = UDim2.new(1, -8, 1, -36),
            Position = UDim2.new(0, 4, 0, 30),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = T.accent,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ZIndex = 62
        })
        mk("UIListLayout", pScroll, { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
        pad(pScroll, 4, 4, 4, 4)

        local function popPicker()
            for _, c in ipairs(pScroll:GetChildren()) do
                if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
            end
            local df = LP:FindFirstChild("Data")
            if not df then return end

            local function getBI(name)
                local pg = LP:FindFirstChildOfClass("PlayerGui")
                if pg then
                    local bf = pg:FindFirstChild("BuildGui") and pg.BuildGui:FindFirstChild("InventoryFrame") and pg.BuildGui.InventoryFrame:FindFirstChild("ScrollingFrame") and pg.BuildGui.InventoryFrame.ScrollingFrame:FindFirstChild("BlocksFrame")
                    if bf then
                        local tpl = bf:FindFirstChild(name)
                        if tpl and tpl:IsA("ImageButton") then return tpl.Image end
                    end
                end
                return ""
            end

            local order = 0
            for _, item in ipairs(df:GetChildren()) do
                if item:IsA("ValueBase") and item.Name:sub(-5) == "Block" then
                    local qty = tonumber(item.Value) or 0
                    if qty > 0 then
                        order = order + 1
                        local fi = getBI(item.Name)
                        local row = mk("TextButton", pScroll, {
                            Size = UDim2.new(1, 0, 0, 36),
                            BackgroundColor3 = T.card,
                            BorderSizePixel = 0,
                            Text = "",
                            LayoutOrder = order,
                            ZIndex = 63
                        })
                        corner(row, 6)
                        mk("ImageLabel", row, {
                            Size = UDim2.new(0, 26, 0, 26),
                            Position = UDim2.new(0, 5, 0.5, -13),
                            BackgroundTransparency = 1,
                            ZIndex = 64,
                            Image = fi ~= "" and fi or "rbxassetid://12328114032"
                        })
                        mk("TextLabel", row, {
                            Size = UDim2.new(1, -80, 1, 0),
                            Position = UDim2.new(0, 36, 0, 0),
                            BackgroundTransparency = 1,
                            Font = Enum.Font.GothamSemibold,
                            TextSize = 11,
                            TextColor3 = T.text,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Text = item.Name,
                            ZIndex = 64
                        })
                        mk("TextLabel", row, {
                            Size = UDim2.new(0, 70, 1, 0),
                            Position = UDim2.new(1, -74, 0, 0),
                            BackgroundTransparency = 1,
                            Font = Enum.Font.GothamBold,
                            TextSize = 11,
                            TextColor3 = T.sub,
                            TextXAlignment = Enum.TextXAlignment.Right,
                            Text = "x" .. tostring(qty),
                            ZIndex = 64
                        })
                        local ci = fi
                        row.MouseButton1Click:Connect(function()
                            updMatBtn(item.Name, ci)
                            matPickOv.Visible = false
                        end)
                    end
                end
            end
            if order == 0 then
                mk("TextLabel", pScroll, {
                    Size = UDim2.new(1, 0, 0, 30),
                    BackgroundTransparency = 1,
                    Text = "No tienes bloques",
                    TextColor3 = T.sub,
                    Font = Enum.Font.Gotham,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Center,
                    ZIndex = 63
                })
            end
        end

        matPickBtn.MouseButton1Click:Connect(function()
            popPicker()
            matPickOv.Visible = true
        end)

        task.defer(function()
            task.wait(0.8)
            local df = LP:FindFirstChild("Data")
            if not df then return end
            local function fI(nm)
                local pg = LP:FindFirstChildOfClass("PlayerGui")
                if pg then
                    local bf = pg:FindFirstChild("BuildGui") and pg.BuildGui:FindFirstChild("InventoryFrame") and pg.BuildGui.InventoryFrame:FindFirstChild("ScrollingFrame") and pg.BuildGui.InventoryFrame.ScrollingFrame:FindFirstChild("BlocksFrame")
                    if bf then
                        local tpl = bf:FindFirstChild(nm)
                        if tpl and tpl:IsA("ImageButton") then return tpl.Image end
                    end
                end
                return ""
            end
            local pb = df:FindFirstChild("PlasticBlock")
            if pb and (tonumber(pb.Value) or 0) > 0 then
                updMatBtn("PlasticBlock", fI("PlasticBlock"))
            else
                for _, item in ipairs(df:GetChildren()) do
                    if item:IsA("ValueBase") and item.Name:sub(-5) == "Block" and (tonumber(item.Value) or 0) > 0 then
                        updMatBtn(item.Name, fI(item.Name))
                        break
                    end
                end
            end
        end)
    end

    -- ══════════════════════════════════════════════
    -- Handles y Arc
    -- ══════════════════════════════════════════════
    local PURPLE_GAMER = Color3.fromRGB(170, 0, 255)
    local Handles = mk("Handles", SG, {
        Adornee = cDummy,
        Style   = Enum.HandlesStyle.Movement,
        Color3  = PURPLE_GAMER,
        Visible = false,
    })
    pcall(function() Handles.AlwaysOnTop = true end)

    local ArcAdornee = mk("Part", envF, {Size=Vector3.new(12,12,12),Transparency=1,Anchored=true,CanCollide=false,CanQuery=false,Material=Enum.Material.Plastic,Position=Vector3.new(0,-9999,0)})
    local Arc = mk("ArcHandles", SG, {
        Adornee = ArcAdornee,
        Color3  = PURPLE_GAMER,
        Visible = false,
    })
    pcall(function() Arc.AlwaysOnTop = true end)

    local function updateHandles()
        local can=(centerPos~=nil) and not locked and PageBuild.Visible
        if can and toolMode=="move" then
            Handles.Adornee = cDummy
            Handles.Visible = true
            Arc.Visible     = false
        elseif can and toolMode=="rotate" then
            Arc.Adornee = ArcAdornee
            Arc.Visible = true
            Handles.Visible = false
        else
            Handles.Visible = false
            Arc.Visible     = false
        end
    end

    -- ══════════════════════════════════════════════
    -- UI ORDEN 6: Mover / Rotar
    -- ══════════════════════════════════════════════
    local bMove, bRotT, moveStepBox, rotStepBox
    local function refreshTool()
        bMove.BackgroundColor3 = (toolMode=="move")   and T.btn or T.btnAlt
        bRotT.BackgroundColor3 = (toolMode=="rotate") and T.btn or T.btnAlt
        updateHandles()
    end
    do
        local rTool=bRow(26)
        bMove=btn(rTool,"",UDim2.new(0,44,0,26),UDim2.new(0,0,0,0),T.btn); mk("ImageLabel",bMove,{Size=UDim2.new(0,18,0,18),Position=UDim2.new(0.5,-9,0.5,-9),BackgroundTransparency=1,Image=ICON_MOVE})
        moveStepBox=mkStepBox(rTool,UDim2.new(0.5,-51,0,26),UDim2.new(0,48,0,0),"1")
        bRotT=btn(rTool,"",UDim2.new(0,44,0,26),UDim2.new(0.5,3,0,0),T.btnAlt); mk("ImageLabel",bRotT,{Size=UDim2.new(0,18,0,18),Position=UDim2.new(0.5,-9,0.5,-9),BackgroundTransparency=1,Image=ICON_ROT})
        rotStepBox=mkStepBox(rTool,UDim2.new(0.5,-51,0,26),UDim2.new(0.5,51,0,0),"15")
        bMove.MouseButton1Click:Connect(function() toolMode="move";   refreshTool() end)
        bRotT.MouseButton1Click:Connect(function() toolMode="rotate"; refreshTool() end)
    end

    -- ══════════════════════════════════════════════
    -- UI ORDEN 7: Posición + Vista previa + Construir
    -- ══════════════════════════════════════════════
    local selBox = mk("SelectionBox", SG, {Color3=T.accent, LineThickness=0.04})
    local BtnBuild, StatLbl, BtnPrev
    local buildUseCZ = true
    local BtnBuildCenter, BtnBuildSel
    local function refreshBuildPlaceBtns()
        if not BtnBuildCenter or not BtnBuildSel then return end
        BtnBuildCenter.BackgroundColor3=buildUseCZ and T.accent or T.btnAlt; BtnBuildCenter.TextColor3=buildUseCZ and T.bg or T.text
        BtnBuildSel.BackgroundColor3=(not buildUseCZ) and T.accent or T.btnAlt; BtnBuildSel.TextColor3=(not buildUseCZ) and T.bg or T.text
    end

    local function getZoneSurface(z)
        if z and z:IsA("BasePart") then
            return z.Position + Vector3.new(0, z.Size.Y/2 + 0.5, 0)
        end
        return Vector3.zero
    end

    local function centerOnClosestZone()
        local z = closestZone(myRefPos())
        if z then
            centerPos         = getZoneSurface(z)
            shapeRot          = CFrame.identity
            hasRot            = false
            cDummy.CFrame     = CFrame.new(centerPos)
            ArcAdornee.CFrame = CFrame.new(centerPos)
            updateHandles()
            markPreview()
            return true
        end
        return false
    end

    do
        local rPos=bRow(28)
        BtnBuildCenter=btn(rPos,"Centro zona",UDim2.new(0.5,-3,1,0),UDim2.new(0,0,0,0),T.accent); BtnBuildCenter.TextColor3=T.bg
        BtnBuildSel=btn(rPos,"Sel. Posición",UDim2.new(0.5,-3,1,0),UDim2.new(0.5,3,0,0),T.btnAlt)
        BtnBuildCenter.MouseButton1Click:Connect(function()
            buildUseCZ=true; refreshBuildPlaceBtns()
            centerOnClosestZone()
        end)
        local bSel2=false
        BtnBuildSel.MouseButton1Click:Connect(function()
            if bSel2 or locked then return end; bSel2=true; buildUseCZ=false; refreshBuildPlaceBtns()
            BtnBuildSel.Text="Haz clic..."
            local rc,cc
            rc=RunService.RenderStepped:Connect(function() selBox.Adornee=Mouse.Target end)
            cc=Mouse.Button1Down:Connect(function()
                local t=Mouse.Target; if t and t:IsA("BasePart") and not t:IsDescendantOf(SG) then
                    centerPos=t.Position; shapeRot=CFrame.identity; hasRot=false
                    cDummy.CFrame=CFrame.new(centerPos); ArcAdornee.CFrame=CFrame.new(centerPos)
                    rc:Disconnect(); cc:Disconnect(); selBox.Adornee=nil; bSel2=false
                    BtnBuildSel.Text="Sel. Posición"; updateHandles(); markPreview()
                end
            end)
        end)

        local rPrev=bRow(32)
        BtnPrev=btn(rPrev,"Vista previa: On",UDim2.new(1,-80,1,0),nil,T.accent); BtnPrev.TextColor3=T.bg
        local prevAlphaFrame=mk("Frame",rPrev,{Size=UDim2.new(0,76,1,0),Position=UDim2.new(1,-76,0,0),BackgroundColor3=T.btnAlt,BorderSizePixel=0}); corner(prevAlphaFrame,6)
        local pAlphaDown=btn(prevAlphaFrame,"-",UDim2.new(0,22,1,0),UDim2.new(0,0,0,0),T.btnAlt)
        local pAlphaLbl=lbl(prevAlphaFrame,math.floor(previewAlpha*100).."%",UDim2.new(0,28,1,0),UDim2.new(0,22,0,0),T.text); pAlphaLbl.TextXAlignment=Enum.TextXAlignment.Center; pAlphaLbl.Font=Enum.Font.GothamBold; pAlphaLbl.TextSize=10
        local pAlphaUp=btn(prevAlphaFrame,"+",UDim2.new(0,22,1,0),UDim2.new(1,-22,0,0),T.btnAlt)
        local function setAlpha(v)
            previewAlpha=math.clamp(v,0,0.95)
            pAlphaLbl.Text=math.floor(previewAlpha*100).."%"
            markPreview()
        end
        pAlphaDown.MouseButton1Click:Connect(function() setAlpha(previewAlpha-0.10) end)
        pAlphaUp.MouseButton1Click:Connect(function() setAlpha(previewAlpha+0.10) end)

        local rBld=bRow(32)
        BtnBuild=btn(rBld,"Construir",UDim2.new(1,0,1,0),nil,T.build); BtnBuild.TextColor3=Color3.new(0,0,0)
        StatLbl=mk("TextLabel",BtnBuild,{Size=UDim2.new(0,100,0,12),Position=UDim2.new(1,-104,1,-16),Text="listo",TextColor3=Color3.new(0,0,0),BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=9,TextXAlignment=Enum.TextXAlignment.Right})
    end
    refreshBuildPlaceBtns()

    local function setStat(t,col) StatLbl.Text=t; StatLbl.TextColor3=col or T.text end

    -- ══════════════════════════════════════════════
    -- FIX CAMBIO DE EQUIPO / respawn
    -- ══════════════════════════════════════════════
    local function waitAndRecenter()
        task.spawn(function()
            for _ = 1, 20 do
                task.wait(0.3)
                local ok, ref = pcall(myRefPos)
                if ok and ref and ref.Y > -100 then
                    local didCenter = centerOnClosestZone()
                    if didCenter then
                        buildUseCZ = true
                        refreshBuildPlaceBtns()
                        needsRecenter = false
                        return
                    end
                end
            end
            needsRecenter = true
        end)
    end

    LP:GetPropertyChangedSignal("Team"):Connect(function()
        if PageBuild.Visible then waitAndRecenter() else needsRecenter = true end
    end)

    LP.CharacterAdded:Connect(function(char)
        local hrp = char:WaitForChild("HumanoidRootPart", 8)
        if not hrp then return end
        task.wait(0.2)
        if PageBuild.Visible then waitAndRecenter() else needsRecenter = true end
    end)

    PageBuild:GetPropertyChangedSignal("Visible"):Connect(function()
        if PageBuild.Visible and needsRecenter then
            needsRecenter = false
            waitAndRecenter()
        end
    end)

    -- ══════════════════════════════════════════════
    -- Handles drag + RenderStepped
    -- CÁMARA: NO se toca Camera.CameraType → queda libre/scriptable como estaba
    -- ══════════════════════════════════════════════
    do
        local drag2, origDP = false, nil
        Handles.MouseButton1Down:Connect(function()
            if not PageBuild.Visible or locked or not centerPos then return end
            drag2 = true; origDP = cDummy.Position
        end)
        Handles.MouseDrag:Connect(function(face, dist)
            if not PageBuild.Visible or not drag2 or not origDP then return end
            local st = stepVal(moveStepBox)
            local d = (st > 0) and (math.floor(dist/st+0.5)*st) or dist
            centerPos = origDP + cDummy.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face))*d
            cDummy.Position = centerPos
            markPreview()
        end)
        Handles.MouseButton1Up:Connect(function()
            if not PageBuild.Visible then return end
            drag2 = false
        end)

        local arcDrag, arcStartRot = false, nil
        local activeArcAxis = nil
        Arc.MouseButton1Down:Connect(function()
            if locked or not centerPos then return end
            arcDrag = true; arcStartRot = shapeRot
        end)
        Arc.MouseDrag:Connect(function(axis, relAngle)
            if not arcDrag then return end
            activeArcAxis = axis
            local av = (axis==Enum.Axis.X and Vector3.xAxis) or (axis==Enum.Axis.Y and Vector3.yAxis) or Vector3.zAxis
            local st = stepVal(rotStepBox)
            local snapped = (st>0) and math.rad(math.floor(math.deg(relAngle)/st+0.5)*st) or relAngle
            shapeRot = arcStartRot * CFrame.fromAxisAngle(av, snapped)
            hasRot = true
            if centerPos then cDummy.CFrame = CFrame.new(centerPos)*shapeRot end
            markPreview()
        end)
        Arc.MouseButton1Up:Connect(function()
            arcDrag = false; activeArcAxis = nil
        end)

        -- RenderStepped: mantiene posición, NO modifica cámara
        RunService.RenderStepped:Connect(function()
            if centerPos then
                local targetCF = hasRot and CFrame.new(centerPos)*shapeRot or CFrame.new(centerPos)
                cDummy.CFrame     = targetCF
                ArcAdornee.CFrame = targetCF
            else
                cDummy.Position     = Vector3.new(0,-9999,0)
                ArcAdornee.Position = Vector3.new(0,-9999,0)
            end

            if PageBuild.Visible and centerPos and not locked then
                if toolMode=="move" then
                    if Handles.Adornee~=cDummy then Handles.Adornee=cDummy end
                    if not Handles.Visible then Handles.Visible=true end
                    if Arc.Visible then Arc.Visible=false end
                elseif toolMode=="rotate" then
                    if Arc.Adornee~=ArcAdornee then Arc.Adornee=ArcAdornee end
                    if not Arc.Visible then Arc.Visible=true end
                    if Handles.Visible then Handles.Visible=false end
                end
            elseif not PageBuild.Visible then
                if Handles.Visible then Handles.Visible=false end
                if Arc.Visible     then Arc.Visible=false end
            end
        end)
    end

    -- ══════════════════════════════════════════════
    -- Preview
    -- ══════════════════════════════════════════════
    local prevPool={}
    local function hidePreview()
        for _,p in ipairs(prevPool) do p.Transparency=1; p.Size=Vector3.new(0.05,0.05,0.05) end
    end
    local function renderPreview(plan)
        local maxP=2500; local stride=1
        if #plan>maxP then stride=math.ceil(#plan/maxP) end
        local n=0
        for i=1,#plan,stride do
            n=n+1
            local p=prevPool[n]
            if not p then
                p=mk("Part",prevF,{Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,CastShadow=false})
                prevPool[n]=p
            end
            p.Size        = plan[i].size
            p.CFrame      = plan[i].cframe
            p.Material    = selBlockMat
            p.Color       = buildUseColor and selColor or selBlockCol
            p.Transparency = previewAlpha
        end
        for i=n+1,#prevPool do
            prevPool[i].Transparency=1; prevPool[i].Size=Vector3.new(0.05,0.05,0.05)
        end
        return #plan,(stride>1)
    end
    local function doPreview()
        if not PageBuild.Visible then hidePreview(); return end
        if not centerPos or not previewOn or locked then hidePreview(); return end
        local plan=generateShape(SHAPES[selShape],centerPos,readParams())
        local minv=Vector3.new(math.huge,math.huge,math.huge)
        local maxv=Vector3.new(-math.huge,-math.huge,-math.huge)
        for _,seg in ipairs(plan) do
            local hS=seg.size/2; local p=seg.cframe.Position
            minv=Vector3.new(math.min(minv.X,p.X-hS.X),math.min(minv.Y,p.Y-hS.Y),math.min(minv.Z,p.Z-hS.Z))
            maxv=Vector3.new(math.max(maxv.X,p.X+hS.X),math.max(maxv.Y,p.Y+hS.Y),math.max(maxv.Z,p.Z+hS.Z))
        end
        if minv.X~=math.huge then
            local size=maxv-minv
            cDummy.Size=Vector3.new(math.clamp(size.X,4,200),math.clamp(size.Y,4,200),math.clamp(size.Z,4,200))
        else
            cDummy.Size=Vector3.new(4,4,4)
        end
        ArcAdornee.Size=cDummy.Size
        local total,sampled=renderPreview(plan)
        if sampled then setStat(("preview %d parts (muestra)"):format(total),T.warn)
        else setStat(("preview %d parts"):format(total),T.sub) end
    end
    RunService.Heartbeat:Connect(function() if prevDirty then prevDirty=false; doPreview() end end)

    onShapeChange=function()
        local def=SHAPES[selShape]; if not def then return end
        if def.kind=="cube3d" then capTopOn=true; capBotOn=true
        elseif def.caps=="bottom" then capTopOn=false; capBotOn=true
        else capTopOn=false; capBotOn=false end
        shapeRot=CFrame.identity; hasRot=false
        if centerPos then cDummy.CFrame=CFrame.new(centerPos) end
        refreshShapes(); refreshCaps(); refreshFill(); refreshBuildRows(); markPreview()
    end

    BtnPrev.MouseButton1Click:Connect(function()
        if locked then return end
        previewOn=not previewOn
        BtnPrev.Text=previewOn and "Vista previa: On" or "Vista previa: Off"
        BtnPrev.BackgroundColor3=previewOn and T.accent or T.btnAlt
        BtnPrev.TextColor3=previewOn and T.bg or T.text
        markPreview()
    end)

    local blockQueue={}; local blockConn=nil
    local function hookFolder(folder)
        if blockConn then blockConn:Disconnect(); blockConn=nil end; blockQueue={}
        if folder then blockConn=folder.ChildAdded:Connect(function(c) blockQueue[#blockQueue+1]=c end) end
    end
    local function popBlock(timeout)
        local t0=tick()
        while #blockQueue==0 do
            if buildState.cancel then return nil end
            if tick()-t0>timeout then return nil end
            task.wait()
        end
        return table.remove(blockQueue,1)
    end
    local function setLocked(s)
        locked=s
        for _,b in ipairs(shapeBtns) do b.Active=not s end
        updateHandles()
    end

    local function iniciarConstruccion()
        if gbRunningRef.value then setStat("ya hay una construcción en curso",T.danger); return end
        if not centerPos then setStat("selecciona un centro primero",T.danger); return end
        local sharing=isSharing(); local activeData,activeName=getActiveData(); local blockStr=selBlockName
        local invItem=activeData and activeData:FindFirstChild(blockStr)
        if not invItem or invItem.Value<=0 then setStat("material no valido / sin stock",T.danger); return end
        local bTool=getActiveTool("BuildingTool"); if not bTool then setStat("falta BuildingTool",T.danger); return end
        local sTool=getActiveTool("ScalingTool"); local pTool=getActiveTool("PaintingTool")
        buildState.running=true; buildState.cancel=false; gbRunningRef.value=true
        BtnBuild.Text="Cancelar"; BtnBuild.BackgroundColor3=T.danger; setLocked(true); hidePreview()
        local ok2,err=pcall(function()
            local plan=generateShape(SHAPES[selShape],centerPos,readParams()); local total=#plan
            if not sharing then equipTool(bTool); equipTool(sTool); if buildUseColor and pTool then equipTool(pTool) end end
            local bRF=bTool and bTool:FindFirstChild("RF"); local sRF=sTool and sTool:FindFirstChild("RF"); local pRF=pTool and pTool:FindFirstChild("RF")
            if not bRF then error("BuildingTool sin RF") end
            local folder=userFolder(LP.Name); hookFolder(folder)
            local placed=0; local placedBlocks={}
            local function placeOne(seg)
                local ret=bRF:InvokeServer(blockStr,invItem.Value,nil,seg.cframe,true,seg.cframe,false)
                local blk
                if typeof(ret)=="Instance" and ret:IsA("BasePart") then blk=ret else blk=popBlock(3) end
                if blk and sRF then pcall(function() sRF:InvokeServer(blk,seg.size,seg.cframe) end) end
                return blk
            end
            local WORKERS=sharing and 6 or 10; local nextIdx=1; local active=WORKERS
            local function worker()
                while true do
                    if buildState.cancel then break end
                    if invItem.Value<=0 then break end
                    local i=nextIdx; nextIdx=nextIdx+1; if i>total then break end
                    if not folder or folder.Parent==nil then folder=userFolder(LP.Name); hookFolder(folder) end
                    local blk=placeOne(plan[i])
                    if blk then placed=placed+1; placedBlocks[#placedBlocks+1]=blk end
                end
                active=active-1
            end
            for _=1,WORKERS do task.spawn(worker) end
            while active>0 do setStat(("Construyendo %d/%d"):format(placed,total),T.warn); task.wait(0.1) end
            if blockConn then blockConn:Disconnect(); blockConn=nil end
            if buildUseColor and pRF and #placedBlocks>0 and not buildState.cancel then
                setStat(("Pintando %d bloques..."):format(#placedBlocks),T.warn)
                local paintData={}
                for _,blk in ipairs(placedBlocks) do paintData[#paintData+1]={blk,selColor} end
                paintBatch(pRF,paintData)
            end
            if buildState.cancel then setStat("Cancelado ("..placed.." colocados)",T.danger)
            else setStat(("listo - %d/%d piezas"):format(placed,total),T.ok) end
        end)
        if blockConn then blockConn:Disconnect(); blockConn=nil end
        if not ok2 then setStat("error: "..tostring(err),T.danger) end
        local hum=LP.Character and LP.Character:FindFirstChild("Humanoid")
        if hum then pcall(function() hum:UnequipTools() end) end
        buildState.running=false; buildState.cancel=false; gbRunningRef.value=false
        BtnBuild.Text="Construir"; BtnBuild.BackgroundColor3=T.build; BtnBuild.TextColor3=Color3.new(0,0,0)
        setLocked(false)
        if previewOn then markPreview() end
    end
    BtnBuild.MouseButton1Click:Connect(function()
        if buildState.running then buildState.cancel=true; setStat("cancelando...",T.danger); return end
        task.spawn(iniciarConstruccion)
    end)

    refreshShapes(); refreshCaps(); refreshFill(); refreshTool(); refreshBuildRows(); onShapeChange()
    task.defer(function() task.wait(0.3); refreshShapes() end)
    task.spawn(function()
        task.wait(1)
        if centerOnClosestZone() then
            buildUseCZ = true
            refreshBuildPlaceBtns()
        end
    end)

    return {
        page        = PageBuild,
        hidePreview = hidePreview,
        markPreview = markPreview,
        handles     = Handles,
        arc         = Arc,
        arcAdornee  = ArcAdornee,
        cDummy      = cDummy,
    }
end

return FormasModule
