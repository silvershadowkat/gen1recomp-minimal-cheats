-- Render real imported ball assets at native resolution, then magnify without
-- filtering. Compare both wobble directions against the original silhouette.
return function(game)
  local ok,err=xpcall(function()
    local S=assert(game.mods.exports.minimal_cheats).silvershadow
    local A,g=S.battleAssets,love.graphics
    local balls={"POKE_BALL","GREAT_BALL","SAFARI_BALL","ULTRA_BALL","MASTER_BALL"}
    local function pixels(item,tilt)
      local canvas=g.newCanvas(16,16,{dpiscale=1});canvas:setFilter("nearest","nearest")
      g.push("all");g.setCanvas(canvas);g.origin();g.clear(0,0,0,0)
      assert(S.captureBalls.draw(item,{x=8,y=8,frame=0,tilt=tilt}))
      g.pop()
      return canvas:newImageData()
    end
    for _,item in ipairs(balls)do
      local neutral=pixels(item,0)
      local palette={}
      for y=0,15 do for x=0,15 do
        local r,b,c,a=neutral:getPixel(x,y)
        if a>0 then palette[string.format("%.3f/%.3f/%.3f",r,b,c)]=true end
      end end
      local function alpha(x,y)
        if x<0 or x>15 or y<0 or y>15 then return 0 end
        local _,_,_,a=neutral:getPixel(x,y);return a
      end
      local changed={}
      for _,tilt in ipairs({-1,1})do
        local data=pixels(item,tilt);local n=0
        for y=0,15 do for x=0,15 do
          local r,b,c,a=data:getPixel(x,y)
          local nr,nb,nc,na=neutral:getPixel(x,y)
          assert(a==na,"wobble changed silhouette: "..item)
          assert(a==0 or a==1,"blurred/partial-alpha pixel")
          if a>0 then
            assert(palette[string.format("%.3f/%.3f/%.3f",r,b,c)],"invented palette color")
            if alpha(x-1,y)==0 or alpha(x+1,y)==0 or alpha(x,y-1)==0 or alpha(x,y+1)==0 then
              assert(r==nr and b==nb and c==nc,"wobble damaged rim: "..item)
            end
            if r~=nr or b~=nb or c~=nc then n=n+1 end
          end
        end end
        assert(n>0,"wobble did not turn markings")
        changed[tilt]=data:getString()
        local img=A.captureBall(item,0,tilt)
        assert(img==A.captureBall(item,0,tilt),"tilt image rebuilt per draw")
        local min,mag=img:getFilter();assert(min=="nearest"and mag=="nearest")
      end
      assert(changed[-1]~=changed[1],"both wobble directions look identical")
      for frame=1,2 do
        local img,q=A.captureBall(item,frame,0)
        local _,y,w,h=q:getViewport()
        assert(img==A.captureSheet and y==frame*16 and w==16 and h==16,"changed open frame")
      end
    end
    for _,item in ipairs({"LOVE_BALL","LURE_BALL","MOON_BALL","FRIEND_BALL","HEAVY_BALL","FAST_BALL","LEVEL_BALL","PARK_BALL"})do
      assert(A.captureBall(item,0,1)==nil,"lost native exclusive-ball fallback: "..item)
    end
    -- Native flipped OAM frames select the opposite tilt, in both generations.
    local gen2=S.generation==2
    for _,flip in ipairs({false,true})do
      local _,p=S.captureBalls.partition({{x=120,y=48,xf=flip,attr=flip and 32 or 0}},
        function()return gen2 and 2 or 6 end)
      assert(p.tilt==(flip and -1 or 1),"OAM tilt direction lost")
    end
    local sheet=g.newCanvas(820,510,{dpiscale=1});sheet:setFilter("nearest","nearest")
    g.push("all");g.setCanvas(sheet);g.origin();g.clear(.94,.95,.96,1)
    g.setColor(.1,.12,.16,1)
    g.print("Capture ball outline: both wobble directions (native pixels enlarged)",16,12)
    for i,item in ipairs(balls)do g.print(item:gsub("_"," "),160+(i-1)*130,45)end
    local rows={{"Upright",0,false},{"Before: left",-1,true},{"Before: right",1,true},
      {"Fixed: left",-1,false},{"Fixed: right",1,false}}
    for r,row in ipairs(rows)do
      local y=80+(r-1)*84
      g.setColor(.1,.12,.16,1);g.print(row[1],16,y+22)
      for i,item in ipairs(balls)do
        local cell=g.newCanvas(24,24,{dpiscale=1});cell:setFilter("nearest","nearest")
        g.push("all");g.setCanvas(cell);g.origin();g.clear(0,0,0,0)
        if row[3]then
          local img,q=A.captureBall(item,0);g.setColor(1,1,1,1)
          g.draw(img,q,12,12,row[2]*math.pi/12,1,1,8,8)
        else S.captureBalls.draw(item,{x=12,y=12,frame=0,tilt=row[2]})end
        g.pop();g.setColor(1,1,1,1);g.draw(cell,170+(i-1)*130,y,0,3,3)
      end
    end
    g.pop()
    local path=os.getenv("SILVERSHADOW_SHOTS").."/capture-ball-outline-comparison.png"
    local file=assert(io.open(path,"wb"));file:write(sheet:newImageData():encode("png"):getString());file:close()
    assert(#game.mods.errors==0,"mod runtime error")
    print("OUTLINE PASS: five balls, both tilts, original silhouette/rim/palette, crisp alpha, cached frames, open frames and native fallback")
  end,debug.traceback)
  if not ok then print("FAIL "..tostring(err))end
  love.event.quit(ok and 0 or 1)
end
