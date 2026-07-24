-- formas.lua
local FormasModule = {}

function FormasModule.init(ENV)
    local mk=ENV.mk; local corner=ENV.corner; local stroke=ENV.stroke; local pad=ENV.pad
    local lbl=ENV.lbl; local box=ENV.box; local btn=ENV.btn; local T=ENV.T
    local SG=ENV.SG; local Body=ENV.Body; local openCP=ENV.openCP
    local RunService=ENV.RunService; local Camera=ENV.Camera; local Mouse=ENV.Mouse
    local envF=ENV.envF; local prevF=ENV.prevF
    local closestZone=ENV.closestZone; local myRefPos=ENV.myRefPos
    local LP=ENV.LP; local equipTool=ENV.equipTool
    local userFolder=ENV.userFolder; local isSharing=ENV.isSharing
    local getActiveData=ENV.getActiveData; local getActiveTool=ENV.getActiveTool
    local paintBatch=ENV.paintBatch; local ICON_MOVE=ENV.ICON_MOVE; local ICON_ROT=ENV.ICON_ROT

    local PB=mk("ScrollingFrame",Body,{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=T.accent,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(0,0,0,0),Visible=false})
    mk("UIListLayout",PB,{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
    pad(PB,10,10,10,10)

    local sS=1; local cP=nil; local pOn=true; local pA=0.55; local lk=false
    local tM="move"; local sR=CFrame.identity; local hR=false
    local cTO=false; local cBO=false; local cFM="strips"
    local bUC=false; local selColor=Color3.fromRGB(255,255,255)
    local sBN="PlasticBlock"; local gbRunRef=ENV.gbRunning; local bS={running=false,cancel=false}
    local sBMat=Enum.Material.Plastic; local sBCol=Color3.fromRGB(163,162,165)
    local needsRecenter=false
    local DEF_IMG="rbxassetid://12328114032"
    local baseCPos = nil -- Posición base en el suelo para calcular offsets

    local function readRealBlockVisual(blockName)
        local folder=userFolder and userFolder(LP.Name)
        if folder then for _,p in ipairs(folder:GetChildren()) do if p:IsA("BasePart") and p.Name==blockName then return p.Material,p.Color end end end
        local function searchR(parent,depth)
            if depth>4 then return nil,nil end
            for _,inst in ipairs(parent:GetChildren()) do
                if inst:IsA("BasePart") and inst.Name==blockName then return inst.Material,inst.Color end
                local m,c=searchR(inst,depth+1); if m then return m,c end
            end
            return nil,nil
        end
        local mat,col=searchR(game:GetService("Workspace"),0)
        if mat then return mat,col end
        local FB={
            WoodBlock={mat=Enum.Material.Wood,col=Color3.fromRGB(133,94,66)},
            PlasticBlock={mat=Enum.Material.Plastic,col=Color3.fromRGB(163,162,165)},
            MetalBlock={mat=Enum.Material.Metal,col=Color3.fromRGB(155,155,155)},
            GlassBlock={mat=Enum.Material.Glass,col=Color3.fromRGB(160,230,255)},
            IceBlock={mat=Enum.Material.Ice,col=Color3.fromRGB(160,230,255)},
            GrassBlock={mat=Enum.Material.Grass,col=Color3.fromRGB(75,151,75)},
            CobblestoneBlock={mat=Enum.Material.Cobblestone,col=Color3.fromRGB(110,110,110)},
            ConcreteBlock={mat=Enum.Material.Concrete,col=Color3.fromRGB(140,140,140)},
            NeonBlock={mat=Enum.Material.Neon,col=Color3.fromRGB(200,200,200)},
        }
        local fb=FB[blockName] or {mat=Enum.Material.Plastic,col=Color3.fromRGB(163,162,165)}
        return fb.mat,fb.col
    end

    local gS,SHAPES
    do
        -- Fuente 5x5 con correcciones en e, y, a, s, f, g, k, x
        local FONT5x5 = {
            A="01110 10001 11111 10001 10001", B="11110 10001 11110 10001 11110", C="01110 10000 10000 10000 01110",
            D="11110 10001 10001 10001 11110", E="11111 10000 11110 10000 11111", F="11111 10000 11110 10000 10000",
            G="01110 10000 10111 10001 01110", H="10001 10001 11111 10001 10001", I="11111 00100 00100 00100 11111",
            J="00111 00010 00010 10010 01100", K="10001 10010 11100 10010 10001", L="10000 10000 10000 10000 11111",
            M="10001 11011 10101 10001 10001", N="10001 11001 10101 10011 10001", ["Ñ"]="01101 10001 11001 10101 10011",
            O="01110 10001 10001 10001 01110", P="11110 10001 11110 10000 10000", Q="01110 10001 10011 01111 00001",
            R="11110 10001 11110 10010 10001", S="01111 10000 01110 00001 11110", T="11111 00100 00100 00100 00100",
            U="10001 10001 10001 10001 01110", V="10001 10001 10001 01010 00100", W="10001 10001 10101 11011 10001",
            X="10001 01010 00100 01010 10001", Y="10001 01010 00100 00100 00100", Z="11111 00010 00100 01000 11111",
            a="01110 00001 01111 10001 01111", b="10000 11110 10001 10001 11110", c="00000 01111 10000 10000 01110",
            d="00001 01111 10001 10001 01111", e="01110 10001 11111 10000 01110", f="01100 10010 11100 10000 10000",
            g="01111 10001 01111 00001 01110", h="10000 11110 10001 10001 10001", i="00100 00000 01100 00100 01100",
            j="00010 00000 00010 10010 01100", k="10001 10010 11100 10010 10001", l="01100 00100 00100 00100 01100",
            m="00000 11010 10101 10101 10001", n="00000 11110 10001 10001 10001", ["ñ"]="01101 00000 11110 10001 10001",
            o="00000 01110 10001 10001 01110", p="00000 11110 10001 11110 10000", q="00000 01111 10001 01111 00001",
            r="00000 10110 11000 10000 10000", s="01111 10000 01110 00001 11110", t="00100 01110 00100 00100 00110",
            u="00000 10001 10001 10001 01111", v="00000 10001 10001 01010 00100", w="00000 10001 10101 10101 01010",
            x="10001 01010 00100 01010 10001", y="10001 10001 01111 00001 01110", z="00000 11111 00010 00100 11111",
            ["0"]="01110 10001 10001 10001 01110", ["1"]="00100 01100 00100 00100 01110", ["2"]="01110 00001 01110 10000 11111",
            ["3"]="11110 00001 01110 00001 11110", ["4"]="10001 10001 11111 00001 00001", ["5"]="11111 10000 11110 00001 11110",
            ["6"]="01110 10000 11110 10001 01110", ["7"]="11111 00001 00010 00100 00100", ["8"]="01110 10001 01110 10001 01110",
            ["9"]="01110 10001 01111 00001 01110", [" "]="00000 00000 00000 00000 00000", ["!"]="00100 00100 00100 00000 00100",
            ["?"]="01110 00001 00110 00000 00100", ["."]="00000 00000 00000 00000 00100", [","]="00000 00000 00000 00100 01000",
        }

        -- Función para recortar los espacios vacíos a los lados de cada caracter
        local TRIMMED_FONT = {}
        for k, v in pairs(FONT5x5) do
            local rows = string.split(v, " ")
            local minC, maxC = 6, 0
            for _, row in ipairs(rows) do
                for c = 1, #row do
                    if row:sub(c, c) == "1" then
                        if c < minC then minC = c end
                        if c > maxC then maxC = c end
                    end
                end
            end
            if minC == 6 then minC = 1; maxC = 1 end -- Para el espacio
            local newRows = {}
            for _, row in ipairs(rows) do
                newRows[#newRows + 1] = row:sub(minC, maxC)
            end
            TRIMMED_FONT[k] = { str = table.concat(newRows, " "), w = (maxC - minC + 1) }
        end

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
                local pos=Vector2.new(a.X+(b.X-a.X)*u2,a.Y+(b.Y-a.Y)*u2)
                local dir=Vector2.new(b.X-a.X,b.Y-a.Y); if dir.Magnitude<0.0001 then dir=Vector2.new(1,0) end
                return pos,dir.Unit
            end
            return eval,tot
        end
        local function placeRing(plan,u,closed,cx,cy,cz,r,bH,th,count)
            local ev,per=buildSampler(u,closed,r); if not ev then return end
            local bL=(per/math.max(1,count))*1.06
            for k=0,count-1 do local pos,dir=ev((k+0.5)/count); local wm=Vector3.new(cx+pos.X,cy,cz+pos.Y); local wd=Vector3.new(dir.X,0,dir.Y); plan[#plan+1]={cframe=CFrame.lookAt(wm,wm+wd),size=Vector3.new(th,bH,bL)} end
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
        local function fillCap(plan,u,cx,cy,cz,r,th,step) if cFM=="grid" then fillGrid(plan,u,cx,cy,cz,r,th,step) else fillStrips(plan,u,cx,cy,cz,r,th,step) end end
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
            for li=0,L-1 do local phi=loS*li; local rR=CFrame.Angles(0,phi,0); for ai=0,M-1 do local a=lS*ai; local lCF=CFrame.new(0,r*math.cos(a),r*math.sin(a))*CFrame.Angles(a,0,0); plan[#plan+1]={cframe=center*rR*lCF,size=Vector3.new(sW,th,sL)} end end
        end
        local function addHalfEllipsoid(plan,cx,cy,cz,r,aL,th,count,top)
            count=math.max(8,count); local L=math.max(3,math.round(math.sqrt(count/2))); local M=math.max(6,L*2)
            local lS=(2*math.pi)/M; local loS=math.pi/L; local sW=r*loS*1.10; local ys=aL/r
            local center=CFrame.new(cx,cy,cz)
            local function cP2(ang) return r*math.cos(ang)*ys,r*math.sin(ang) end
            for li=0,L-1 do local phi=loS*li; local rR=CFrame.Angles(0,phi,0)
                for ai=0,M-1 do local a=lS*ai; local cosa=math.cos(a); local keep=top and(cosa>=-1e-6)or((not top)and(cosa<=1e-6))
                    if keep then local yy=r*cosa*ys; local y0,z0=cP2(a-lS/2); local y1,z1=cP2(a+lS/2); local dy,dz=y1-y0,z1-z0; local sLen=math.sqrt(dy*dy+dz*dz); if sLen<1e-6 then dy,dz,sLen=0,1,1 end; local nx,ny,nz=0,dz,-dy; local nm=math.sqrt(ny*ny+nz*nz); if nm<1e-9 then nm=1 end; local lCF=CFrame.fromMatrix(Vector3.new(0,yy,r*math.sin(a)),Vector3.new(1,0,0),Vector3.new(nx,ny/nm,nz/nm),Vector3.new(0,dy/sLen,dz/sLen)); plan[#plan+1]={cframe=center*rR*lCF,size=Vector3.new(sW,th,sLen*1.10)} end
                end
            end
        end
        local function buildPyramid(plan,cx,cy,cz,r,h,th,count,p01,cB)
            local hs=r; local expo=0.5+p01*2.5; local layers=math.clamp(math.floor(count/4+0.5),3,160); local lH=h/layers
            local faces={{dir=Vector3.new(1,0,0),side=Vector3.new(0,0,1)},{dir=Vector3.new(-1,0,0),side=Vector3.new(0,0,1)},{dir=Vector3.new(0,0,1),side=Vector3.new(1,0,0)},{dir=Vector3.new(0,0,-1),side=Vector3.new(1,0,0)}}
            local function prof(t) return hs*((1-t)^expo) end
            for _,f in ipairs(faces) do for i=0,layers-1 do local t0=i/layers; local t1=(i+1)/layers; local tc=(i+0.5)/layers; local dc=prof(tc); local yc=(cy-h/2)+tc*h; local pBot=f.dir*prof(t0)+Vector3.new(0,(cy-h/2)+t0*h,0); local pTop=f.dir*prof(t1)+Vector3.new(0,(cy-h/2)+t1*h,0); local u=(pTop-pBot); local sL=u.Magnitude; if sL<1e-4 then u=Vector3.new(0,1,0); sL=lH else u=u.Unit end; local v=f.side; local n2=u:Cross(v); if n2:Dot(f.dir)<0 then v=-v; n2=u:Cross(v) end; n2=n2.Unit; v=v.Unit; local width=2*dc; if width<1e-3 then width=sL*0.5 end; plan[#plan+1]={cframe=CFrame.fromMatrix(Vector3.new(cx,0,cz)+f.dir*dc+Vector3.new(0,yc,0),v,n2),size=Vector3.new(width*1.04,th,sL*1.05)} end end
            if cB then fillCap(plan,SQ,cx,cy-h/2+th/2,cz,hs,th,(2*hs)/math.max(4,layers)) end
        end
        local function buildCapsule(plan,cx,cy,cz,r,h,th,count,p01)
            local circle=circPts(96); local capL=r*(1+p01*1.5); local bodyH=math.max(h,0)
            if bodyH>0.01 then placeRing(plan,circle,true,cx,cy,cz,r,bodyH,th,count) end
            addHalfEllipsoid(plan,cx,cy+bodyH/2,cz,r,capL,th,count,true)
            addHalfEllipsoid(plan,cx,cy-bodyH/2,cz,r,capL,th,count,false)
        end
        local function buildText(plan, cx, cy, cz, P)
            local text = P.text or "TEXTO"
            if #text == 0 then return end
            local pxSize = math.max(0.1, P.overallSize or 1)
            local thick = math.max(0.1, P.thick or 1)
            local spaceSize = math.max(0, P.letterSpacing or 1) * pxSize
            local scaleX = math.max(0.1, P.letterWidth or 1)
            local scaleY = math.max(0.1, P.letterHeight or 1)
            local charH = 5 * pxSize * scaleY

            local lines = { text }
            local totalH = #lines * charH + (#lines - 1) * spaceSize
            local startY = totalH / 2

            for _, line in ipairs(lines) do
                local lineWidth = 0
                for i = 1, #line do
                    local ch = line:sub(i,i)
                    local isSpace = (ch == " ")
                    local charData = TRIMMED_FONT[ch] or TRIMMED_FONT[ch:upper()] or TRIMMED_FONT["?"]
                    local w = isSpace and 2 or charData.w
                    lineWidth = lineWidth + (w * pxSize * scaleX)
                    if i < #line then lineWidth = lineWidth + spaceSize end
                end

                local currentX = -lineWidth / 2
                for i = 1, #line do
                    local ch = line:sub(i,i)
                    local isSpace = (ch == " ")
                    local charData = isSpace and {str="0", w=2} or (TRIMMED_FONT[ch] or TRIMMED_FONT[ch:upper()] or TRIMMED_FONT["?"])
                    local w = charData.w
                    local wSize = w * pxSize * scaleX

                    if not isSpace then
                        local rows = string.split(charData.str, " ")
                        for r=1, #rows do
                            local rowStr = rows[r]
                            for c=1, #rowStr do
                                if rowStr:sub(c,c) == "1" then
                                    local blockX = currentX + (c - 0.5) * pxSize * scaleX
                                    local blockY = startY - (r - 0.5) * pxSize * scaleY
                                    plan[#plan+1] = {
                                        cframe = CFrame.new(cx + blockX, cy + blockY, cz),
                                        size = Vector3.new(pxSize * scaleX, pxSize * scaleY, thick)
                                    }
                                end
                            end
                        end
                    end
                    currentX = currentX + wSize + spaceSize
                end
                startY = startY - charH - spaceSize
            end
        end

        SHAPES={
            {label="Circulo",icon="circle",kind="extrude",pts=function() return circPts(96) end,caps="both",fillable=true,useHeight=true,useCount=true,usePoint=false, yOffset=3},
            {label="Cuadrado",icon="square",kind="extrude",pts=function() return polyPts(4,math.pi/4) end,caps="both",fillable=true,useHeight=true,useCount=true,usePoint=false, yOffset=3},
            {label="Corazon",icon="heart",kind="extrude",pts=heartPts,caps="both",fillable=true,useHeight=true,useCount=true,usePoint=false, yOffset=3},
            {label="Cubo",icon="cube",kind="cube3d",caps="both",fillable=false,useHeight=false,useCount=true,usePoint=false, yOffset=20},
            {label="Esfera",icon="sphere",kind="sphere3d",caps=false,fillable=false,useHeight=false,useCount=true,usePoint=false, yOffset=20},
            {label="Piramide",icon="pyramid",kind="pyramid",caps="bottom",fillable=true,useHeight=true,useCount=true,usePoint=true,pointy=true, yOffset=4},
            {label="Capsula",icon="capsule",kind="capsule",caps=false,fillable=false,useHeight=true,useCount=true,usePoint=true,pointy=true, yOffset=24},
            {label="Texto",icon="text",kind="text",caps=false,fillable=false,useHeight=false,useCount=false,usePoint=false, yOffset=2, rot=CFrame.Angles(0, math.rad(-90), 0)},
        }
        gS=function(def,cp,P)
            local plan={}; if not cp then return plan end
            local cx,cy,cz=cp.X,cp.Y,cp.Z; local k=def.kind
            if k=="extrude" then buildExtruded(plan,def.pts(),cx,cy,cz,P.radius,P.height,P.thick,P.count,P.capTop,P.capBottom)
            elseif k=="cube3d" then buildCube(plan,cx,cy,cz,P.radius,P.thick,P.count,P.capTop,P.capBottom)
            elseif k=="sphere3d" then buildSphere(plan,cx,cy,cz,P.radius,P.thick,P.count)
            elseif k=="pyramid" then buildPyramid(plan,cx,cy,cz,P.radius,P.height,P.thick,P.count,P.point,P.capBottom)
            elseif k=="capsule" then buildCapsule(plan,cx,cy,cz,P.radius,P.height,P.thick,P.count,P.point)
            elseif k=="text" then buildText(plan, cx, cy, cz, P)
            end
            if hR then local pivot=CFrame.new(cx,cy,cz); local rot=pivot*sR*pivot:Inverse(); for _,s in ipairs(plan) do s.cframe=rot*s.cframe end end
            return plan
        end
    end

    local drawIcon
    do
        local function dLine(par,x1,y1,x2,y2,col)
            local dx,dy=x2-x1,y2-y1; local len=math.sqrt(dx*dx+dy*dy); if len<1 then return end
            mk("Frame",par,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromOffset((x1+x2)/2,(y1+y2)/2),Size=UDim2.fromOffset(len,2),BorderSizePixel=0,BackgroundColor3=col,Rotation=math.deg(math.atan2(dy,dx))})
        end
        drawIcon=function(container,def,col)
            for _,c in ipairs(container:GetChildren()) do if not c:IsA("UICorner") and not c:IsA("UIStroke") then c:Destroy() end end
            local bsz=container.AbsoluteSize.X; if bsz<=0 then bsz=30 end
            local R=(bsz/2)-3; local cx2,cy2=bsz/2,bsz/2; local ic=def.icon
            if ic=="circle" then local ring=mk("Frame",container,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(R*2,R*2),BackgroundTransparency=1}); corner(ring,999); mk("UIStroke",ring,{Color=col,Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
            elseif ic=="square" then local s=R*0.85; dLine(container,cx2-s,cy2-s,cx2+s,cy2-s,col); dLine(container,cx2+s,cy2-s,cx2+s,cy2+s,col); dLine(container,cx2+s,cy2+s,cx2-s,cy2+s,col); dLine(container,cx2-s,cy2+s,cx2-s,cy2-s,col)
            elseif ic=="sphere" then local ring=mk("Frame",container,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(R*2,R*2),BackgroundTransparency=1}); corner(ring,999); mk("UIStroke",ring,{Color=col,Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border}); dLine(container,cx2-R,cy2,cx2+R,cy2,col)
            elseif ic=="cube" then local s=R*0.6; local o=R*0.5; local fr={{-s,-s},{s,-s},{s,s},{-s,s}}; local bk={}; for i,c2 in ipairs(fr) do bk[i]={c2[1]+o,c2[2]-o} end; for i=1,4 do local a,b2=fr[i],fr[(i%4)+1]; local a2,b3=bk[i],bk[(i%4)+1]; dLine(container,cx2+a[1],cy2+a[2],cx2+b2[1],cy2+b2[2],col); dLine(container,cx2+a2[1],cy2+a2[2],cx2+b3[1],cy2+b3[2],col); dLine(container,cx2+a[1],cy2+a[2],cx2+a2[1],cy2+a2[2],col) end
            elseif ic=="pyramid" then local tx,ty=cx2,cy2-R; local blx,bly=cx2-R,cy2+R*0.8; local brx,bry=cx2+R,cy2+R*0.8; dLine(container,tx,ty,blx,bly,col); dLine(container,tx,ty,brx,bry,col); dLine(container,blx,bly,brx,bry,col); dLine(container,tx,ty,cx2+R*0.35,bry,col)
            elseif ic=="capsule" then local st=mk("Frame",container,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(R*1.2,R*2),BackgroundTransparency=1}); corner(st,999); mk("UIStroke",st,{Color=col,Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
            elseif ic=="heart" then local scale=R*0.82; local pts={}; local N=32; for k2=0,N-1 do local t=(k2/N)*2*math.pi; local px=16*math.sin(t)^3; local py=-(13*math.cos(t)-5*math.cos(2*t)-2*math.cos(3*t)-math.cos(4*t)); pts[k2+1]={cx2+px*scale/17,cy2+py*scale/17} end; for i=1,N do local a2=pts[i]; local b2=pts[(i%N)+1]; dLine(container,a2[1],a2[2],b2[1],b2[2],col) end
            elseif ic=="text" then 
                mk("TextLabel", container, {
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    Text = "abc",
                    TextColor3 = col,
                    Font = Enum.Font.GothamBold,
                    TextSize = bsz * 0.45
                })
            end
        end
    end

    local BInput={}
    local PARAM_MINS={radius=0.01,height=0.01,thick=0.01,count=4,point=0}
    local rP=function()
        return {
            radius=math.max(PARAM_MINS.radius,tonumber(BInput.bRadius and BInput.bRadius.Text) or 20),
            height=math.max(PARAM_MINS.height,tonumber(BInput.bSizeY and BInput.bSizeY.Text) or 8),
            thick=math.max(PARAM_MINS.thick,tonumber(BInput.bThick and BInput.bThick.Text) or 1),
            count=math.max(PARAM_MINS.count,math.floor(tonumber(BInput.bSteps and BInput.bSteps.Text) or 120)),
            point=math.clamp(tonumber(BInput.bPunta and BInput.bPunta.Text) or 0,0,1),
            capTop=cTO,capBottom=cBO,
            text=(BInput.bText and BInput.bText.Text) or "TEXTO",
            overallSize=math.max(0.1,tonumber(BInput.bOverallSize and BInput.bOverallSize.Text) or 1),
            letterWidth=math.max(0.1,tonumber(BInput.bLetterWidth and BInput.bLetterWidth.Text) or 1),
            letterHeight=math.max(0.1,tonumber(BInput.bLetterHeight and BInput.bLetterHeight.Text) or 1),
            letterSpacing=math.max(0,tonumber(BInput.bLetterSpace and BInput.bLetterSpace.Text) or 1),
        }
    end

    local cDummy=mk("Part",envF,{Size=Vector3.new(4,4,4),Transparency=1,Color=T.accent,Anchored=true,CanCollide=false,CanQuery=false,Material=Enum.Material.Plastic,Position=Vector3.new(0,-9999,0)})

    local rowBuild={}
    local function bRow(h,visFn)
        local f=mk("Frame",PB,{Size=UDim2.new(1,0,0,h),BackgroundTransparency=1,LayoutOrder=#rowBuild+1})
        rowBuild[#rowBuild+1]={frame=f,vis=visFn}
        return f
    end
    local function refreshBuildRows() for _,r in ipairs(rowBuild) do r.frame.Visible=(r.vis==nil) or r.vis() end end

    local function bindHold(b,fn)
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

    local pD=false
    local function mPv() pD=true end

    local function mkNumRow(row,label,default,step,minVal)
        lbl(row,label,UDim2.new(0,72,1,0),UDim2.new(0,0,0,0),T.sub)
        local bl=btn(row,"-",UDim2.new(0,24,0,24),UDim2.new(0,76,0,0),T.btnAlt)
        local bx=box(row,UDim2.new(1,-132,0,24),UDim2.new(0,104,0,0),default)
        bx.TextXAlignment=Enum.TextXAlignment.Center
        local br=btn(row,"+",UDim2.new(0,24,0,24),UDim2.new(1,-24,0,0),T.btnAlt)
        local decimal=(step<1) or (minVal~=nil and minVal<1)
        local function fmt(n) if minVal then n=math.max(minVal,n) end; if decimal then if n==math.floor(n) then return tostring(math.floor(n)) else return string.format("%.2f",n) end else return tostring(math.floor(n+0.5)) end end
        local function smartStep(cur,dir)
            if minVal~=nil and dir<0 and cur<=minVal+0.0001 then return minVal end
            if decimal then local curIsInt=(math.abs(cur-math.floor(cur+0.5))<0.0001); if curIsInt then local iv=math.floor(cur+0.5); if dir>0 then return iv>=1 and(iv+1) or math.floor((cur+0.1)*100+0.5)/100 else if iv>1 then return math.max(minVal or -math.huge,iv-1) elseif iv==1 then return math.max(minVal or -math.huge,0.9) else local nx=cur<=0.1+0.0001 and math.floor((cur-0.01)*1000+0.5)/1000 or math.floor((cur-0.1)*100+0.5)/100; return minVal and math.max(minVal,nx) or nx end end else if dir>0 then if cur<0.1-0.0001 then return math.floor((cur+0.01)*1000+0.5)/1000 else local ni=math.floor(cur)+1; return(ni-cur<=0.1+0.0001) and ni or math.floor((cur+0.1)*100+0.5)/100 end else local nx=cur<=0.1+0.0001 and math.floor((cur-0.01)*1000+0.5)/1000 or math.floor((cur-0.1)*100+0.5)/100; return minVal and math.max(minVal,nx) or nx end end else local nx=math.floor(cur+dir*step+0.5); return minVal and math.max(minVal,nx) or nx end
        end
        local guard=false
        bx:GetPropertyChangedSignal("Text"):Connect(function() if guard then return end; local c=cleanNum(bx.Text); if c~=bx.Text then guard=true; bx.Text=c; guard=false end; mPv() end)
        bx.FocusLost:Connect(function() local v=tonumber(bx.Text); if not v or bx.Text=="" then local fb=minVal or tonumber(default) or 0; guard=true; bx.Text=fmt(fb); guard=false; mPv() elseif minVal and v<minVal then guard=true; bx.Text=fmt(minVal); guard=false; mPv() end end)
        bindHold(bl,function() local cur=tonumber(bx.Text); if not cur then cur=minVal or 0 end; bx.Text=fmt(smartStep(cur,-1)); mPv() end)
        bindHold(br,function() local cur=tonumber(bx.Text); if not cur then cur=minVal or 0 end; bx.Text=fmt(smartStep(cur,1)); mPv() end)
        return bx
    end

    local function stepVal(bx) local v=tonumber(bx and bx.Text); if not v or v<0 then v=0 end; return v end
    local function mkStepBox(parent,size,pos,default)
        local bx=box(parent,size,pos,default); bx.TextXAlignment=Enum.TextXAlignment.Center
        local guard=false
        bx:GetPropertyChangedSignal("Text"):Connect(function() if guard then return end; local c=cleanNum(bx.Text); if c~=bx.Text then guard=true; bx.Text=c; guard=false end end)
        bx.FocusLost:Connect(function() local v=tonumber(bx.Text); if not v or v<0 then guard=true; bx.Text="0"; guard=false end end)
        return bx
    end

    local shapeBtns={}; local shapeIcons={}; local onShapeChange
    local function rfS()
        for i,b in ipairs(shapeBtns) do
            local sel=(i==sS); b.BackgroundColor3=sel and T.btn or T.btnAlt
            local st=b:FindFirstChildOfClass("UIStroke"); if st then st.Enabled=sel end
            if shapeIcons[i] then task.defer(function() drawIcon(shapeIcons[i],SHAPES[i],sel and T.text or T.accent) end) end
        end
    end

    do
        local rGrid=bRow(90)
        mk("UIGridLayout",rGrid,{CellSize=UDim2.new(0,38,0,38),CellPadding=UDim2.new(0,6,0,6),SortOrder=Enum.SortOrder.LayoutOrder})
        rGrid.BackgroundTransparency=1
        for i,def in ipairs(SHAPES) do
            if type(def)=="table" and def.label then
                local b=mk("TextButton",rGrid,{Text="",BackgroundColor3=T.btnAlt,TextColor3=T.text,BorderSizePixel=0,LayoutOrder=i,AutoButtonColor=false}); corner(b,8)
                local st=stroke(b,T.accent,2); st.Enabled=false
                local ic=mk("Frame",b,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(0,26,0,26),BackgroundTransparency=1})
                shapeBtns[i]=b; shapeIcons[i]=ic
                b.MouseButton1Click:Connect(function() sS=i; if onShapeChange then onShapeChange() end end)
                task.defer(function() task.wait(0.1); drawIcon(ic,def,T.accent) end)
            end
        end
    end

    do
        local rTxt=bRow(24, function() local d=SHAPES[sS]; return d and d.kind=="text" end)
        lbl(rTxt, "Texto", UDim2.new(0,72,1,0), UDim2.new(0,0,0,0), T.sub)
        local txtBox=box(rTxt, UDim2.new(1,-132,0,24), UDim2.new(0,104,0,0), "TEXTO")
        txtBox.TextXAlignment=Enum.TextXAlignment.Center
        BInput.bText=txtBox
        txtBox.FocusLost:Connect(function() mPv() end)
        txtBox:GetPropertyChangedSignal("Text"):Connect(mPv)

        local rRad=bRow(24, function() local d=SHAPES[sS]; return d and d.kind~="text" end); BInput.bRadius=mkNumRow(rRad,"Radio","20",1,0.01)
        local rCnt=bRow(24,function() local d=SHAPES[sS]; return d and d.useCount~=false end); BInput.bSteps=mkNumRow(rCnt,"Parts","120",4,4)
        local rHgt=bRow(24,function() local d=SHAPES[sS]; return d and d.useHeight==true end); BInput.bSizeY=mkNumRow(rHgt,"Altura","8",1,0.01)
        local rThk=bRow(24); BInput.bThick=mkNumRow(rThk,"Grosor","1",0.1,0.01)
        local rPnt=bRow(24,function() local d=SHAPES[sS]; return d and d.usePoint==true end); BInput.bPunta=mkNumRow(rPnt,"Punta","0",0.1,0)

        local rTxtW=bRow(24, function() local d=SHAPES[sS]; return d and d.kind=="text" end)
        BInput.bLetterWidth=mkNumRow(rTxtW, "Ancho L.", "1", 0.1, 0.1)

        local rTxtH=bRow(24, function() local d=SHAPES[sS]; return d and d.kind=="text" end)
        BInput.bLetterHeight=mkNumRow(rTxtH, "Alto L.", "1", 0.1, 0.1)

        local rTxtS=bRow(24, function() local d=SHAPES[sS]; return d and d.kind=="text" end)
        BInput.bLetterSpace=mkNumRow(rTxtS, "Espacio", "1", 0.1, 0)

        local rTxtB=bRow(24, function() local d=SHAPES[sS]; return d and d.kind=="text" end)
        BInput.bOverallSize=mkNumRow(rTxtB, "Tam. Bloq", "1", 0.1, 0.1)
    end

    local cBT,cBB
    local function rfC()
        local def=SHAPES[sS]
        if def and def.caps=="bottom" then
            cBT.Visible=false; cBB.Visible=true
            cBB.Text="▼ Tapa base"; cBB.Size=UDim2.new(0,150,0,22)
            cBB.AnchorPoint=Vector2.new(0,0.5); cBB.Position=UDim2.new(0,52,0.5,0)
        else
            cBT.Visible=true; cBB.Visible=true
            cBT.Text="▲ Tapa Sup"; cBB.Text="▼ Tapa Inf"
            cBT.Size=UDim2.new(0,88,0,22); cBT.AnchorPoint=Vector2.new(0,0.5); cBT.Position=UDim2.new(0,52,0.5,0)
            cBB.Size=UDim2.new(0,88,0,22); cBB.AnchorPoint=Vector2.new(0,0.5); cBB.Position=UDim2.new(0,146,0.5,0)
        end
        cBT.BackgroundColor3=cTO and T.build or T.btnAlt
        cBB.BackgroundColor3=cBO and T.build or T.btnAlt
    end
    do
        local rCap=bRow(26,function() local d=SHAPES[sS]; return d and d.caps~=false end)
        local tapL=lbl(rCap,"Tapas",UDim2.new(0,50,1,0),UDim2.new(0,0,0,0),T.sub); tapL.AnchorPoint=Vector2.new(0,0.5); tapL.Position=UDim2.new(0,0,0.5,0)
        cBT=btn(rCap,"▲ Tapa Sup",UDim2.new(0,88,0,22),nil,T.btnAlt); cBT.AnchorPoint=Vector2.new(0,0.5); cBT.Position=UDim2.new(0,52,0.5,0)
        cBB=btn(rCap,"▼ Tapa Inf",UDim2.new(0,88,0,22),nil,T.btnAlt); cBB.AnchorPoint=Vector2.new(0,0.5); cBB.Position=UDim2.new(0,146,0.5,0)
        cBT.MouseButton1Click:Connect(function() cTO=not cTO; rfC(); mPv() end)
        cBB.MouseButton1Click:Connect(function() cBO=not cBO; rfC(); mPv() end)
    end

    local fSB,fGB
    local function rfF()
        fSB.BackgroundColor3=(cFM=="strips") and T.build or T.btnAlt
        fGB.BackgroundColor3=(cFM=="grid") and T.build or T.btnAlt
    end
    do
        local rFill=bRow(24,function() local d=SHAPES[sS]; return d and d.fillable==true and(cTO or cBO) end)
        lbl(rFill,"Relleno",UDim2.new(0,50,1,0),nil,T.sub)
        fSB=btn(rFill,"Tiras",UDim2.new(0,80,0,24),UDim2.new(0,52,0,0),T.build)
        fGB=btn(rFill,"Bloques",UDim2.new(0,80,0,24),UDim2.new(0,138,0,0),T.btnAlt)
        fSB.MouseButton1Click:Connect(function() cFM="strips"; rfF(); mPv() end)
        fGB.MouseButton1Click:Connect(function() cFM="grid"; rfF(); mPv() end)
    end

    local sBNRef={value="PlasticBlock"}
    local matPickOv,matPickBtn,mLabelRef,mIconRef

    local function updMatBtn(nm,iconId)
        sBNRef.value=nm; sBN=nm
        if mLabelRef then mLabelRef.Text=nm end
        if mIconRef then mIconRef.Image=iconId or DEF_IMG end
        task.spawn(function() local mat,col=readRealBlockVisual(nm); sBMat=mat; sBCol=col; mPv() end)
    end

    do
        local rColorMat=bRow(28)
        local colBtnInd=mk("Frame",rColorMat,{Size=UDim2.new(0,22,0,22),Position=UDim2.new(0,4,0.5,-11),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0})
        corner(colBtnInd,11); stroke(colBtnInd,T.text,1.5)
        local bOP=btn(rColorMat,"Elegir color",UDim2.new(0,80,0,24),UDim2.new(0,30,0.5,-12),T.btn)
        local bTC=btn(rColorMat,"ON",UDim2.new(0,36,0,24),UDim2.new(0,114,0.5,-12),T.btnAlt)
        local function refCB() bTC.BackgroundColor3=bUC and T.build or T.btnAlt; bTC.Text=bUC and "ON" or "OFF" end
        refCB()
        bTC.MouseButton1Click:Connect(function() bUC=not bUC; refCB(); mPv() end)
        bOP.MouseButton1Click:Connect(function()
            openCP(selColor,function(col) selColor=col; colBtnInd.BackgroundColor3=col; bUC=true; refCB(); mPv() end,
            function(col) selColor=col; colBtnInd.BackgroundColor3=col; if bUC then mPv() end end)
        end)
        matPickBtn=mk("TextButton",rColorMat,{Size=UDim2.new(1,-160,0,24),Position=UDim2.new(0,156,0.5,-12),BackgroundColor3=T.input,BorderSizePixel=0,Font=Enum.Font.GothamSemibold,TextSize=10,Text="",TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left})
        corner(matPickBtn,6)
        mIconRef=mk("ImageLabel",matPickBtn,{Size=UDim2.new(0,20,0,20),Position=UDim2.new(0,4,0.5,-10),BackgroundTransparency=1,BorderSizePixel=0})
        mLabelRef=mk("TextLabel",matPickBtn,{Size=UDim2.new(1,-32,1,0),Position=UDim2.new(0,28,0,0),BackgroundTransparency=1,Font=Enum.Font.GothamSemibold,TextSize=10,TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left,Text=sBNRef.value})
        matPickOv=mk("Frame",ENV.Win,{Size=UDim2.new(1,0,1,0),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0.35,BorderSizePixel=0,Visible=false,ZIndex=60})
        mk("TextButton",matPickOv,{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",ZIndex=60,AutoButtonColor=false}).MouseButton1Click:Connect(function() matPickOv.Visible=false end)
        local pBox=mk("Frame",matPickOv,{Size=UDim2.new(1,-20,0.85,0),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,0),BackgroundColor3=T.panel,BorderSizePixel=0,ZIndex=61})
        corner(pBox,10)
        mk("TextLabel",pBox,{Size=UDim2.new(1,0,0,28),BackgroundTransparency=1,Text="ELEGIR BLOQUE",TextColor3=T.text,Font=Enum.Font.GothamBold,TextSize=12,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=62})
        local pScroll=mk("ScrollingFrame",pBox,{Size=UDim2.new(1,-8,1,-36),Position=UDim2.new(0,4,0,30),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=T.accent,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(0,0,0,0),ZIndex=62})
        mk("UIListLayout",pScroll,{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder})
        pad(pScroll,4,4,4,4)
        local function getBI(name)
            local pg=LP:FindFirstChildOfClass("PlayerGui")
            if pg then local bf=pg:FindFirstChild("BuildGui") and pg.BuildGui:FindFirstChild("InventoryFrame") and pg.BuildGui.InventoryFrame:FindFirstChild("ScrollingFrame") and pg.BuildGui.InventoryFrame.ScrollingFrame:FindFirstChild("BlocksFrame"); if bf then local tpl=bf:FindFirstChild(name); if tpl and tpl:IsA("ImageButton") then return tpl.Image end end end
            return ""
        end
        local function popPicker()
            for _,c in ipairs(pScroll:GetChildren()) do if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end end
            local df=LP:FindFirstChild("Data"); if not df then return end
            local order=0
            for _,item in ipairs(df:GetChildren()) do
                if item:IsA("ValueBase") and item.Name:sub(-5)=="Block" then
                    local qty=tonumber(item.Value) or 0
                    if qty>0 then
                        order=order+1
                        local fi=getBI(item.Name)
                        local row=mk("TextButton",pScroll,{Size=UDim2.new(1,0,0,36),BackgroundColor3=T.card,BorderSizePixel=0,Text="",LayoutOrder=order,ZIndex=63})
                        corner(row,6)
                        mk("ImageLabel",row,{Size=UDim2.new(0,26,0,26),Position=UDim2.new(0,5,0.5,-13),BackgroundTransparency=1,ZIndex=64,Image=fi~="" and fi or DEF_IMG})
                        mk("TextLabel",row,{Size=UDim2.new(1,-80,1,0),Position=UDim2.new(0,36,0,0),BackgroundTransparency=1,Font=Enum.Font.GothamSemibold,TextSize=11,TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left,Text=item.Name,ZIndex=64})
                        mk("TextLabel",row,{Size=UDim2.new(0,70,1,0),Position=UDim2.new(1,-74,0,0),BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextSize=11,TextColor3=T.sub,TextXAlignment=Enum.TextXAlignment.Right,Text="x"..item.Value,ZIndex=64})
                        local ci=fi
                        row.MouseButton1Click:Connect(function() updMatBtn(item.Name,ci); matPickOv.Visible=false end)
                    end
                end
            end
            if order==0 then mk("TextLabel",pScroll,{Size=UDim2.new(1,0,0,30),BackgroundTransparency=1,Text="No tienes bloques",TextColor3=T.sub,Font=Enum.Font.Gotham,TextSize=11,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=63}) end
        end
        matPickBtn.MouseButton1Click:Connect(function() popPicker(); matPickOv.Visible=true end)
        task.defer(function()
            task.wait(0.8)
            local df=LP:FindFirstChild("Data"); if not df then return end
            local pb=df:FindFirstChild("PlasticBlock")
            if pb and (tonumber(pb.Value) or 0)>0 then updMatBtn("PlasticBlock",getBI("PlasticBlock"))
            else for _,item in ipairs(df:GetChildren()) do if item:IsA("ValueBase") and item.Name:sub(-5)=="Block" and (tonumber(item.Value) or 0)>0 then updMatBtn(item.Name,getBI(item.Name)); break end end
            end
        end)
    end

    local PURPLE_GAMER=Color3.fromRGB(170,0,255)
    local Handles=mk("Handles",SG,{Adornee=cDummy,Style=Enum.HandlesStyle.Movement,Color3=PURPLE_GAMER,Visible=false})
    pcall(function() Handles.AlwaysOnTop=true end)
    local ArcAdornee=mk("Part",envF,{Size=Vector3.new(12,12,12),Transparency=1,Anchored=true,CanCollide=false,CanQuery=false,Material=Enum.Material.Plastic,Position=Vector3.new(0,-9999,0)})
    local Arc=mk("ArcHandles",SG,{Adornee=ArcAdornee,Color3=PURPLE_GAMER,Visible=false})
    pcall(function() Arc.AlwaysOnTop=true end)

    local function updateHandles()
        local can=(cP~=nil) and not lk and PB.Visible
        if can and tM=="move" then Handles.Adornee=cDummy; Handles.Visible=true; Arc.Visible=false
        elseif can and tM=="rotate" then Arc.Adornee=ArcAdornee; Arc.Visible=true; Handles.Visible=false
        else Handles.Visible=false; Arc.Visible=false end
    end

    local bMove,bRotT,moveStepBox,rotStepBox
    local function rfT()
        bMove.BackgroundColor3=(tM=="move") and T.btn or T.btnAlt
        bRotT.BackgroundColor3=(tM=="rotate") and T.btn or T.btnAlt
        updateHandles()
    end
    do
        local rTool=bRow(26)
        bMove=btn(rTool,"",UDim2.new(0,44,0,26),UDim2.new(0,0,0,0),T.btn); mk("ImageLabel",bMove,{Size=UDim2.new(0,18,0,18),Position=UDim2.new(0.5,-9,0.5,-9),BackgroundTransparency=1,Image=ICON_MOVE})
        moveStepBox=mkStepBox(rTool,UDim2.new(0.5,-51,0,26),UDim2.new(0,48,0,0),"1")
        bRotT=btn(rTool,"",UDim2.new(0,44,0,26),UDim2.new(0.5,3,0,0),T.btnAlt); mk("ImageLabel",bRotT,{Size=UDim2.new(0,18,0,18),Position=UDim2.new(0.5,-9,0.5,-9),BackgroundTransparency=1,Image=ICON_ROT})
        rotStepBox=mkStepBox(rTool,UDim2.new(0.5,-51,0,26),UDim2.new(0.5,51,0,0),"15")
        bMove.MouseButton1Click:Connect(function() tM="move"; rfT() end)
        bRotT.MouseButton1Click:Connect(function() tM="rotate"; rfT() end)
    end

    local selBox=mk("SelectionBox",SG,{Color3=T.accent,LineThickness=0.04})
    local BB,SL,BPr; local bCZ=true; local BtnBldC,BtnBldS
    local function rfBP()
        if not BtnBldC or not BtnBldS then return end
        BtnBldC.BackgroundColor3=bCZ and T.accent or T.btnAlt; BtnBldC.TextColor3=bCZ and T.bg or T.text
        BtnBldS.BackgroundColor3=(not bCZ) and T.accent or T.btnAlt; BtnBldS.TextColor3=(not bCZ) and T.bg or T.text
    end

    local function getZoneSurface(z)
        if z and z:IsA("BasePart") then return z.Position+Vector3.new(0,z.Size.Y/2+0.5,0) end
        return Vector3.zero
    end

    local function centerOnCZ()
        local z=closestZone(myRefPos())
        if z then 
            baseCPos = getZoneSurface(z)
            local def = SHAPES[sS]
            local yOff = def and def.yOffset or 0
            cP = baseCPos + Vector3.new(0, yOff, 0)
            sR = def and def.rot or CFrame.identity
            hR = sR ~= CFrame.identity
            cDummy.CFrame=CFrame.new(cP)*sR
            ArcAdornee.CFrame=CFrame.new(cP)*sR
            updateHandles(); mPv(); return true 
        end
        return false
    end

    do
        local rPos=bRow(28)
        BtnBldC=btn(rPos,"Centro zona",UDim2.new(0.5,-3,1,0),UDim2.new(0,0,0,0),T.accent); BtnBldC.TextColor3=T.bg
        BtnBldS=btn(rPos,"Sel. Posición",UDim2.new(0.5,-3,1,0),UDim2.new(0.5,3,0,0),T.btnAlt)
        BtnBldC.MouseButton1Click:Connect(function() bCZ=true; rfBP(); centerOnCZ() end)
        local bSel2=false
        BtnBldS.MouseButton1Click:Connect(function()
            if bSel2 or lk then return end; bSel2=true; bCZ=false; rfBP()
            BtnBldS.Text="Haz clic..."
            local rc,cc
            rc=RunService.RenderStepped:Connect(function() selBox.Adornee=Mouse.Target end)
            cc=Mouse.Button1Down:Connect(function()
                local t=Mouse.Target; if t and t:IsA("BasePart") and not t:IsDescendantOf(SG) then
                    baseCPos=t.Position
                    local def = SHAPES[sS]
                    local yOff = def and def.yOffset or 0
                    cP = baseCPos + Vector3.new(0, yOff, 0)
                    sR = def and def.rot or CFrame.identity
                    hR = sR ~= CFrame.identity
                    cDummy.CFrame=CFrame.new(cP)*sR
                    ArcAdornee.CFrame=CFrame.new(cP)*sR
                    rc:Disconnect(); cc:Disconnect(); selBox.Adornee=nil; bSel2=false
                    BtnBldS.Text="Sel. Posición"; updateHandles(); mPv()
                end
            end)
        end)

        local rPrev=bRow(32)
        BPr=btn(rPrev,"Vista previa: On",UDim2.new(1,-80,1,0),nil,T.accent); BPr.TextColor3=T.bg
        local prevAlphaFrame=mk("Frame",rPrev,{Size=UDim2.new(0,76,1,0),Position=UDim2.new(1,-76,0,0),BackgroundColor3=T.btnAlt,BorderSizePixel=0}); corner(prevAlphaFrame,6)
        local pAlphaDown=btn(prevAlphaFrame,"-",UDim2.new(0,22,1,0),UDim2.new(0,0,0,0),T.btnAlt)
        local pAlphaLbl=lbl(prevAlphaFrame,math.floor(pA*100).."%",UDim2.new(0,28,1,0),UDim2.new(0,22,0,0),T.text); pAlphaLbl.TextXAlignment=Enum.TextXAlignment.Center; pAlphaLbl.Font=Enum.Font.GothamBold; pAlphaLbl.TextSize=10
        local pAlphaUp=btn(prevAlphaFrame,"+",UDim2.new(0,22,1,0),UDim2.new(1,-22,0,0),T.btnAlt)
        local function setAlpha(v) pA=math.clamp(v,0,0.95); pAlphaLbl.Text=math.floor(pA*100).."%"; mPv() end
        pAlphaDown.MouseButton1Click:Connect(function() setAlpha(pA-0.10) end)
        pAlphaUp.MouseButton1Click:Connect(function() setAlpha(pA+0.10) end)

        local rBld=bRow(32)
        BB=btn(rBld,"Construir",UDim2.new(1,0,1,0),nil,T.build); BB.TextColor3=Color3.new(0,0,0)
        SL=mk("TextLabel",BB,{Size=UDim2.new(0,100,0,12),Position=UDim2.new(1,-104,1,-16),Text="listo",TextColor3=Color3.new(0,0,0),BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=9,TextXAlignment=Enum.TextXAlignment.Right})
    end
    rfBP()

    local function setStat(t,col) SL.Text=t; SL.TextColor3=col or T.text end

    local function waitAndRecenter()
        task.spawn(function()
            for _=1,20 do
                task.wait(0.3)
                local ok,ref=pcall(myRefPos)
                if ok and ref and ref.Y>-100 then
                    local didCenter=centerOnCZ()
                    if didCenter then bCZ=true; rfBP(); needsRecenter=false; return end
                end
            end
            needsRecenter=true
        end)
    end

    LP:GetPropertyChangedSignal("Team"):Connect(function() if PB.Visible then waitAndRecenter() else needsRecenter=true end end)
    LP.CharacterAdded:Connect(function(char)
        local hrp=char:WaitForChild("HumanoidRootPart",8); if not hrp then return end
        task.wait(0.2)
        if PB.Visible then waitAndRecenter() else needsRecenter=true end
    end)
    PB:GetPropertyChangedSignal("Visible"):Connect(function() if PB.Visible and needsRecenter then needsRecenter=false; waitAndRecenter() end end)

    do
        local drag2,savedCam,origDP=false,nil,nil
        Handles.MouseButton1Down:Connect(function() if not PB.Visible or lk or not cP then return end; drag2=true; origDP=cDummy.Position; savedCam=Camera.CFrame; Camera.CameraType=Enum.CameraType.Scriptable end)
        Handles.MouseDrag:Connect(function(face,dist)
            if not PB.Visible or not drag2 or not origDP then return end
            local st=stepVal(moveStepBox)
            local d=(st>0)and(math.floor(dist/st+0.5)*st)or dist
            local moveVec = cDummy.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face))*d
            cP = cP + moveVec
            if baseCPos then baseCPos = baseCPos + moveVec end
            cDummy.Position = cP
            mPv()
        end)
        Handles.MouseButton1Up:Connect(function() if not PB.Visible then return end; drag2=false; savedCam=nil; Camera.CameraType=Enum.CameraType.Custom end)
        local arcDrag,arcStartRot,arcSavedCam=false,nil,nil; local activeArcAxis=nil
        Arc.MouseButton1Down:Connect(function() if lk or not cP then return end; arcDrag=true; arcStartRot=sR; arcSavedCam=Camera.CFrame; Camera.CameraType=Enum.CameraType.Scriptable end)
        Arc.MouseDrag:Connect(function(axis,relAngle) if not arcDrag then return end; if activeArcAxis~=axis then activeArcAxis=axis end; local av=(axis==Enum.Axis.X and Vector3.xAxis)or(axis==Enum.Axis.Y and Vector3.yAxis)or Vector3.zAxis; local st=stepVal(rotStepBox); local snapped=(st>0)and math.rad(math.floor(math.deg(relAngle)/st+0.5)*st)or relAngle; sR=arcStartRot*CFrame.fromAxisAngle(av,snapped); hR=true; if cP then cDummy.CFrame=CFrame.new(cP)*sR end; mPv() end)
        Arc.MouseButton1Up:Connect(function() arcDrag=false; arcSavedCam=nil; activeArcAxis=nil; Camera.CameraType=Enum.CameraType.Custom end)
        RunService.RenderStepped:Connect(function()
            if drag2 and savedCam then Camera.CFrame=savedCam end
            if arcDrag and arcSavedCam then Camera.CFrame=arcSavedCam end
            if cP and hR then cDummy.CFrame=CFrame.new(cP)*sR elseif cP then cDummy.Position=cP end
            if cP then ArcAdornee.CFrame=CFrame.new(cP)*sR else ArcAdornee.Position=Vector3.new(0,-9999,0) end
            if PB.Visible and cP and not lk then
                if tM=="move" then if Handles.Adornee~=cDummy then Handles.Adornee=cDummy end; if not Handles.Visible then Handles.Visible=true end; if Arc.Visible then Arc.Visible=false end
                elseif tM=="rotate" then if Arc.Adornee~=ArcAdornee then Arc.Adornee=ArcAdornee end; if not Arc.Visible then Arc.Visible=true end; if Handles.Visible then Handles.Visible=false end end
            elseif not PB.Visible then if Handles.Visible then Handles.Visible=false end; if Arc.Visible then Arc.Visible=false end end
        end)
    end

    local pp={}
    local function hPv() for _,p in ipairs(pp) do p.Transparency=1; p.Size=Vector3.new(0.05,0.05,0.05) end end
    local function rnP(plan)
        local maxP=2500; local stride=1
        if #plan>maxP then stride=math.ceil(#plan/maxP) end
        local n=0
        for i=1,#plan,stride do
            n=n+1; local p=pp[n]
            if not p then p=mk("Part",prevF,{Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,CastShadow=false}); pp[n]=p end
            p.Size=plan[i].size; p.CFrame=plan[i].cframe; p.Material=sBMat
            p.Color=bUC and selColor or sBCol; p.Transparency=pA
        end
        for i=n+1,#pp do pp[i].Transparency=1; pp[i].Size=Vector3.new(0.05,0.05,0.05) end
        return #plan,(stride>1)
    end
    local function dPv()
        if not PB.Visible then hPv(); return end
        if not cP or not pOn or lk then hPv(); return end
        local plan=gS(SHAPES[sS],cP,rP())
        local minv=Vector3.new(math.huge,math.huge,math.huge); local maxv=Vector3.new(-math.huge,-math.huge,-math.huge)
        for _,seg in ipairs(plan) do local hS=seg.size/2; local p=seg.cframe.Position; minv=Vector3.new(math.min(minv.X,p.X-hS.X),math.min(minv.Y,p.Y-hS.Y),math.min(minv.Z,p.Z-hS.Z)); maxv=Vector3.new(math.max(maxv.X,p.X+hS.X),math.max(maxv.Y,p.Y+hS.Y),math.max(maxv.Z,p.Z+hS.Z)) end
        if minv.X~=math.huge then local size=maxv-minv; cDummy.Size=Vector3.new(math.clamp(size.X,4,200),math.clamp(size.Y,4,200),math.clamp(size.Z,4,200)) else cDummy.Size=Vector3.new(4,4,4) end
        ArcAdornee.Size=cDummy.Size
        local total,sampled=rnP(plan)
        if sampled then setStat(("preview %d parts (muestra)"):format(total),T.warn) else setStat(("preview %d parts"):format(total),T.sub) end
    end
    RunService.Heartbeat:Connect(function() if pD then pD=false; dPv() end end)

    onShapeChange=function()
        local def=SHAPES[sS]; if not def then return end
        if def.kind=="cube3d" then cTO=true; cBO=true
        elseif def.caps=="bottom" then cTO=false; cBO=true
        else cTO=false; cBO=false end
        
        sR = def.rot or CFrame.identity
        hR = sR ~= CFrame.identity
        
        if baseCPos then
            cP = baseCPos + Vector3.new(0, def.yOffset or 0)
            cDummy.CFrame=CFrame.new(cP)*sR
            ArcAdornee.CFrame=CFrame.new(cP)*sR
        end
        rfS(); rfC(); rfF(); refreshBuildRows(); mPv()
    end

    BPr.MouseButton1Click:Connect(function()
        if lk then return end
        pOn=not pOn
        BPr.Text=pOn and "Vista previa: On" or "Vista previa: Off"
        BPr.BackgroundColor3=pOn and T.accent or T.btnAlt
        BPr.TextColor3=pOn and T.bg or T.text
        mPv()
    end)

    local blockQueue={}; local blockConn=nil
    local function hookFolder(folder) if blockConn then blockConn:Disconnect(); blockConn=nil end; blockQueue={}; if folder then blockConn=folder.ChildAdded:Connect(function(c) blockQueue[#blockQueue+1]=c end) end end
    local function popBlock(timeout)
        local t0=tick()
        while #blockQueue==0 do if bS.cancel then return nil end; if tick()-t0>timeout then return nil end; task.wait() end
        return table.remove(blockQueue,1)
    end
    local function setLocked(s) lk=s; for _,b in ipairs(shapeBtns) do b.Active=not s end; updateHandles() end

    local function iniciarConstruccion()
        if gbRunRef.value then setStat("ya hay una construcción en curso",T.danger); return end
        if not cP then setStat("selecciona un centro primero",T.danger); return end
        local sharing=isSharing(); local activeData=getActiveData()
        local invItem=activeData and activeData:FindFirstChild(sBN)
        if not invItem or invItem.Value<=0 then setStat("material no valido / sin stock",T.danger); return end
        local bTool=getActiveTool("BuildingTool"); if not bTool then setStat("falta BuildingTool",T.danger); return end
        local sTool=getActiveTool("ScalingTool"); local pTool=getActiveTool("PaintingTool")
        bS.running=true; bS.cancel=false; gbRunRef.value=true
        BB.Text="Cancelar"; BB.BackgroundColor3=T.danger; setLocked(true); hPv()
        local ok2,err=pcall(function()
            local plan=gS(SHAPES[sS],cP,rP()); local total=#plan
            if not sharing then equipTool(bTool); equipTool(sTool); if bUC and pTool then equipTool(pTool) end end
            local bRF=bTool and bTool:FindFirstChild("RF"); local sRF=sTool and sTool:FindFirstChild("RF"); local pRF=pTool and pTool:FindFirstChild("RF")
            if not bRF then error("BuildingTool sin RF") end
            local folder=userFolder(LP.Name); hookFolder(folder)
            local placed=0; local pBl={}
            local function placeOne(seg)
                local ret=bRF:InvokeServer(sBN,invItem.Value,nil,seg.cframe,true,seg.cframe,false)
                local blk
                if typeof(ret)=="Instance" and ret:IsA("BasePart") then blk=ret else blk=popBlock(3) end
                if blk and sRF then pcall(function() sRF:InvokeServer(blk,seg.size,seg.cframe) end) end
                return blk
            end
            local WORKERS=sharing and 15 or 50; local nextIdx=1; local active=WORKERS
            local function worker()
                while true do
                    if bS.cancel then break end
                    if invItem.Value<=0 then break end
                    local i=nextIdx; nextIdx=nextIdx+1; if i>total then break end
                    if not folder or folder.Parent==nil then folder=userFolder(LP.Name); hookFolder(folder) end
                    local blk=placeOne(plan[i])
                    if blk then placed=placed+1; pBl[#pBl+1]=blk end
                end
                active=active-1
            end
            for _=1,WORKERS do task.spawn(worker) end
            while active>0 do setStat(("Construyendo %d/%d"):format(placed,total),T.warn); task.wait(0.03) end
            if blockConn then blockConn:Disconnect(); blockConn=nil end
            if bUC and pRF and #pBl>0 and not bS.cancel then
                setStat(("Pintando %d bloques..."):format(#pBl),T.warn)
                local paintData={}; for _,blk in ipairs(pBl) do paintData[#paintData+1]={blk,selColor} end
                paintBatch(pRF,paintData)
            end
            if bS.cancel then setStat("Cancelado ("..placed.." colocados)",T.danger) else setStat(("listo - %d/%d piezas"):format(placed,total),T.ok) end
        end)
        if blockConn then blockConn:Disconnect(); blockConn=nil end
        if not ok2 then setStat("error: "..tostring(err),T.danger) end
        local hum=LP.Character and LP.Character:FindFirstChild("Humanoid")
        if hum then pcall(function() hum:UnequipTools() end) end
        bS.running=false; bS.cancel=false; gbRunRef.value=false
        BB.Text="Construir"; BB.BackgroundColor3=T.build; BB.TextColor3=Color3.new(0,0,0)
        setLocked(false)
        if pOn then mPv() end
    end
    BB.MouseButton1Click:Connect(function()
        if bS.running then bS.cancel=true; setStat("cancelando...",T.danger); return end
        task.spawn(iniciarConstruccion)
    end)

    rfS(); rfC(); rfF(); rfT(); refreshBuildRows(); onShapeChange()
    task.defer(function() task.wait(0.3); rfS() end)
    task.spawn(function() task.wait(1); if centerOnCZ() then bCZ=true; rfBP() end end)

    return {
        page=PB, hidePreview=hPv, markPreview=mPv,
        handles=Handles, arc=Arc, arcAdornee=ArcAdornee, cDummy=cDummy,
    }
end

return FormasModule
