pico-8 cartridge // http://www.pico-8.com
version 29
__lua__

track_t=0
scene_t=0
efct_t=0
race_len=10000
spin_ln=60
hit=0
banana_prob=10
oil_prob=75
oil_decel=0.018
spd=0
trgt_spd=1
accel=0.015
max_spd=4
trn_spd=0.1
decel=0.05
dash_l=7
dash_spc=5
street_w=72
py=64
px0=0
px=0
pdy=0
min_spd=0.2

junk={}

function _init()
end

function _update60()
 if(track_t>race_len) then
  if btnp(4) or btnp(5) then
   run()
  end
  return
 end
 get_input()
 move_player()
 spawn_junk()
 update_junk()
 get_collisions()
 track_t+=(spd)
 if hit>0 then
  hit-=1
 end
 efct_t+=1
end

function _draw()
 palt(15,true)
 palt(0,false)
 cls()
 if(track_t>race_len) then
  print('finish!',46,48,14)
  print('score: '..efct_t/60\1,40,62,7)
  rect(38,60,80,68,8)
  print('press ❎ or 🅾️ to restart',16,90,7)
  return
 end
 draw_street()
 draw_fin()
 draw_junk()
 draw_player()
 draw_map()
 print(((spd*30)\1)..' mph',50,110,10)
 print('time: '..efct_t/60\1,40,0,8)
end

function get_input()
 if btn(3) then
  pdy+=trn_spd
 end
 if btn(2) then
  pdy-=trn_spd
 end
end

function move_player()
 spd=lerp(spd,trgt_spd,0.01)
 trgt_spd+=accel
 trgt_spd=min(trgt_spd,max_spd)
 pdy*=1-decel
 if not(btn(2) or btn(3)) then
  if(abs(pdy)<min_spd)pdy=0
 end
 py+=pdy 
 py=mid(60-street_w/2,py,52+street_w/2)
end

function get_collisions()
 if(hit>0)return
 local ptop=(py-24)\12+1
 local pbot=(py-17)\12+1
 local lns=ptop==pbot and {ptop} or {ptop,pbot}
 local oil_collided=false
 for j in all(junk) do
  if mid(j.x-15,px,j.x+(j.w-1)*8)==px then
   if contains(lns,j.ln) then
    if j.typ=='banana' then
     hit+=60
     trgt_spd*=0.25
    elseif j.typ=='oil' then
     if(oil_collided)break
     trgt_spd*=(1-oil_decel)
     oil_collided=true
    end
   end
  end
 end
end

function contains(obj,val)
 for v in all(obj) do
  if(v==val)return true
 end
 return false
end

function spawn_junk()
 if(rnd(1000)<banana_prob*(spd/max_spd))add(junk,banana_obj())
 if(rnd(1000)<oil_prob*(spd/max_spd))add(junk,oil_obj())
end

function update_junk()
 for j in all(junk) do
  j.x-=(spd)
  if(j.x<-j.w*8)del(junk,j)
 end
end

function draw_junk()
 for j in all(junk) do
  local y=get_lane_y(j.ln)
  for i=1,j.w do
   local s_off=(i==1 and 0 or (i==j.w and 2 or 1))
   local x_off=(i-1)*8
   spr(j.spr+s_off,j.x+x_off,y)
  end
 end
end

function banana_obj()
 return {
  typ='banana',
  spr=6,
  w=1,
  x=128,
  ln=rnd(6)\1+1
 }
end

function oil_obj()
 local w=rnd(8)\1+1
 local s=(w==1 and 33 or 49)
 return {
  typ='oil',
  spr=s,
  w=w,
  x=128,
  ln=rnd(6)\1+1,
 }
end

function draw_street()
 local w2=street_w/2
 rectfill(0,63-w2,127,64+w2,5)
 line(0,63-w2,127,63-w2,6)
 line(0,64+w2,127,64+w2,6)
 local cyc=dash_l+dash_spc
 local t_off=track_t%cyc
 for x=-t_off,127,cyc do
  rectfill(x,63,x+dash_l-1,64,10)
 end
end

function draw_fin()
 local w2=street_w/2
 local x=128-((track_t+100)-race_len)
 for i=0,8 do
  spr(7,x,28+i*8)
 end
end

function draw_player()
 px=px0+spd*15
 local pr=pdy*20
 pr+=(hit/spin_ln)*360
 rspr(3,px,py,pr,2,2)
end

function draw_map()
 line(30,17,97,17,7)
 local perc=track_t/race_len
 local x=26+(70*perc)
 local y=9+(sin(efct_t/60)*2)
 spr(22,x,y)
 spr(38,97,10)
end

function get_lane_y(l)
 return 18+l*12
end

function lerp(v1,v2,r)
 return v1+(v2-v1)*r
end

function rspr(s,x,y,a,w,h)
 sw=(w or 1)*8
 sh=(h or 1)*8
 sx=(s%8)*8
 sy=flr(s/8)*8
 x0=flr(0.5*sw)
 y0=flr(0.5*sh)
 a=a/360
 sa=sin(a)
 ca=cos(a)
 for ix=0,sw-1 do
  for iy=0,sh-1 do
   dx=ix-x0
   dy=iy-y0
   xx=flr(dx*ca-dy*sa+x0)
   yy=flr(dx*sa+dy*ca+y0)
   if (xx>=0 and xx<sw and yy>=0 and yy<=sh)then
    local c=sget(sx+xx,sy+yy)
    if(c~=15)pset(x+ix,y+iy,c)
   end
  end
 end
end


__gfx__
00000000fffffffffffffffffffffffffffffffffffffffffff4ffff000077770000000000000000000000000000000000000000000000000000000000000000
00000000fffffffffffffffffffffffffffffffffffffffffa0a0fff000077770000000000000000000000000000000000000000000000000000000000000000
00700700fffffffffffffffffffffffffffffffffffffffffa0a0fff000077770000000000000000000000000000000000000000000000000000000000000000
00077000fffffffffffffffffffffffffffffffffffffffffaaaa0ff000077770000000000000000000000000000000000000000000000000000000000000000
00077000fff000fff000fffffff000fff000fffffffffffff00aa0ff777700000000000000000000000000000000000000000000000000000000000000000000
00700700ff88888888888fffff88888888888fffffffffffffaaaa0f777700000000000000000000000000000000000000000000000000000000000000000000
00000000f88c87778cc888fff88c88888cc888ffffffffffaaa00aaa777700000000000000000000000000000000000000000000000000000000000000000000
00000000f8cc707078cc888ff9cc999999cc998fffffffff000ff000777700000000000000000000000000000000000000000000000000000000000000000000
00000000f8cc777778cc888ffecceeeeeeccee8fffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000
00000000f88c87878cc888fff88c88888cc888ffffffffffeeeeeeee000000000000000000000000000000000000000000000000000000000000000000000000
00000000ff88888888888fffff88888888888fffffffffff8eeeeee8000000000000000000000000000000000000000000000000000000000000000000000000
00000000fff000fff000fffffff000fff000fffffffffffff8eeee88000000000000000000000000000000000000000000000000000000000000000000000000
00000000ffffffffffffffffffffffffffffffffffffffffff8ee88f000000000000000000000000000000000000000000000000000000000000000000000000
00000000fffffffffffffffffffffffffffffffffffffffffff888ff000000000000000000000000000000000000000000000000000000000000000000000000
00000000ffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000
00000000ffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000
00000000ff0000ffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000
00000000f000000ffffffffffffffffffffffffffffffffff557fff5000000000000000000000000000000000000000000000000000000000000000000000000
0000000000006000ffffffffffffffffffffffffffffffff45577557000000000000000000000000000000000000000000000000000000000000000000000000
0000000000060000ffffffffffffffffffffffffffffffff47755775000000000000000000000000000000000000000000000000000000000000000000000000
0000000000600060ffffffffffffffffffffffffffffffff47755775000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000600ffffffffffffffffffffffffffffffff45577557000000000000000000000000000000000000000000000000000000000000000000000000
00000000f000600fffffffffffffffffffffffffffffffff45577557000000000000000000000000000000000000000000000000000000000000000000000000
00000000ff0000ffffffffffffffffffffffffffffffffff4fff577f000000000000000000000000000000000000000000000000000000000000000000000000
00000000ff0000000000000000000fffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000
00000000f000000000000000006000ffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000
0000000000060000000000000600000fffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000
0000000000600000000600000000000fffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000006000000000600fffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000
000000000000006000000000000600ffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000
00000000f00006000000000000000fffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000
00000000ff000000000000000000ffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000
