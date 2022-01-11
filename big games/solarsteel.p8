pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
--solar steel
--by fuzzy_dunlop

global_t=0
wins={[1]=0,[2]=0}
g_sword={
 full_length=20,
 length=20,
 curve=2,
 detail=10,  
 h_length=3,
 full_h_length=3
}

state_defaults={
 max_speed=.75,--1.5
 accel=.25,
 turn_speed=.02,
 deadzone_width=5/360,
 fb_deadzone_width=90/360,
 max_turn_angle=20/360,
 drag=.95,
 atk_accel=0
}

last_inp_t=0
in_tutorial=false
letter_h=15

in_intro=true
player_died=0

g_draw_fight=false

feet={
  spacing=2,
  width=3,
 }
 
min_player_speed=.08

fx={
 trail_length=.2,
 trail_bits=4,
 trail_size=.5,
 trail_life=4,
 orbit_speed=1,
 orbit_angle=0,
 blend_rate=.06,
 gravity=-30,
 max_particles=50,
 p_dist_size_change=40,
 min_core_dist=5,
 shadow_life=10,
 shadow_num=2,
 shadow_dist=4.5,
 star_speed=60,
 full_star_speed=220,
 star_turn_speed=.005,
 injury1_rate=90,
 injury2_rate=30
}


function _init()
 music(32)
 clear_background()
 init_generate_stars()
 _update60=menu_intro_update
 _draw=menu_intro_draw
end  


function game_update()
 global_t+=1
 check_no_inp(3600)
 player_manager:update()
 make_stars(10)
 make_erasers()
 update_stars()
 new_update_particles()
 update_sun()
 add_sword_shadows()
 add_parry_trails()
 random_fly_dir()
 if player_died>0 then
  fx.max_particles=100
  fx.star_speed-=1.5
  fx.star_speed=max(10,fx.star_speed)
  player_died+=1
  if player_died>60 then
   if btnp(4,0) or btnp(4,1) then
    reload()
    fx.max_particles=50
    game_init()
    _update60=game_intro_update
   end
   if btnp(5,0) 
   or btnp(5,1) then
    run()
   end
  end
 end
end


function game_draw()
 if(global_t==0) return
 do_shake()
 do_background()
 draw_sun()
 draw_starz()
 new_draw_sword_trails()
 new_draw_sword_shadows()
 draw_parry_trails()
 player_manager:draw()
 letterbox()
 if (g_draw_fight) draw_fight()
 if player_died>30 then
  if player_died<48 then
   if player_died%3<2 then
    draw_ded()
   end
  else
   draw_ded()
   draw_instr()
  end
 end
 setpal()
-- print(stat(7),0,6,7)
-- print('cpu usage='..(stat(1)*100)..'%',0,6,7)
end


function do_background()
 memcpy(0x0,0x2000,0x1000)
 draw_stars()
 draw_sun_shadow()
 screen_dither()
 draw_background()
 if in_intro then
  minskycirc(intro_x,64,1,10)
  minskycirc(127-intro_x,64,1,6)
 end
 memcpy(0x2000,0x0,0x1000)
 memcpy(0x0,0x4300,0x1000)
end

function clear_background()
 memcpy(0x4300,0x0,0x1000)
 memset(0x0,0,0x2000)
end

function check_no_inp(n)
 if (global_t-last_inp_t>n) run()
end

function fadepal()
 pal(8,2,1)
 pal(4,1,1)
 pal(15,1,1)
end

function setpal()
 pal(3,136,1)
 pal(10,135,1)
 pal(4,141,1)
 pal(15,131,1)
 pal(8,8,1)
end

-->8
--player manager

player_manager={
 players={},
 clear_players=function(self)
  self.players={}
 end,
 make_player=function(self,id,x,y,ornt,a_name,c)
  local p={ 

   cache={
--    ca_ornt=nil,
--    sa_ornt=nil
   },
--   force_event=nil,

   input_disabled=true,
   
   id=id,
   c=c,
   
   died=false,
   redbody=false,
   
   x=x,
   y=y,
   drawx=x,
   drawy=y,
   dx=0,
   dy=0,
   ornt=ornt,
   events={
--    was_pry=false,
--    pry_succ=false,
--    was_hit=false,
--    hit_succ=false
   },
   
   hitbox={
    w=8,
    h=4,
--    h_o=0,
--    v_o=.5,
   },
   
   parrybox={
    w=29,
    h=28,
    h_o=-5,
    v_o=-14,
   },
   
   feet_a=0,
   feet_h=10,
   feet_jitter=0,
 
   feet={
    l={
     x=0,
     y=0
    },
    r={
     x=0,
     y=0
    }
   },
   
   injuries=0,
   wins=0,
   
   atk_part=0,
  }
  p.a=anmtr.init(a_name,x,y)
  p.s=state_manager.init(a_name)
  p.i=input_manager.init()
  self.players[id]=p
 end,

 update=function(self)
  local funcs={
   self.update_caches,
   self.check_hits,
   self.get_inputs,
   self.update_states,
   self.update_anims,
   self.move_players,
   self.orient_players,
   self.update_blades,
   self.update_feet
  }
  self:do_series(funcs)  
 end,
 
 draw=function(self)
  for p in all(self.players) do
   self:draw_health(p)
  end
  local funcs={
--  	self.draw_health,
	  self.draw_feet,
	  self.draw_blades,
	  self.draw_players
  }
  self:do_series(funcs)
 end,
 
 update_caches=function(self,p)
   p.cache.ca_ornt=cos(p.ornt)
   p.cache.sa_ornt=sin(p.ornt)
 end,
 
 update_blades=function(self,p)
   local name=p.s.state.name
   local thrusting=name=='thr' or name=='thr_windup' or name=='thr_succ' 
   local curve=thrusting and 0 or g_sword.curve
   local s_ornt=(p.ornt+.25*(p.s.reversed and -1 or 3))%1
   p.a:get_blade(sin(s_ornt),cos(s_ornt),curve,p.s.state.name=='pry')
 end,
 
 get_inputs=function(self,p)
   if(p.input_disabled) return
   local op_dir=self:get_other_player_dir(p)
   p.i:update(p,op_dir)
 end,
  
 update_anims=function(self,p)
   if(p.s.changed) then
    p.atk_part=0
    p.a:set_anim(p.s.state.name,p.s.reversed)
   else
    p.a:adv_frame()
   end
 end,
 
 move_players=function(self,p)
   if(p.input_disabled or in_tutorial) return
   local x_accel,y_accel=p.i.movement.x_input,p.i.movement.y_input
   local diag=abs(x_accel==1) and abs(y_accel==1)
   local acc=(diag and .707 or 1)*p.s:get_setting('accel')
   local current_vec={x=p.dx,y=p.dy}
   current_vec=mlt_vector(current_vec,p.s:get_setting('drag'))    
   local dragged_mag=pythag(current_vec)
   if dragged_mag<min_player_speed then
    current_vec=mlt_vector(current_vec,0)
   end
   if(p.a.s_data[8]==1) then
    local atk_accel_vec=make_vector(p.cache.ca_ornt,p.cache.sa_ornt,p.s:get_setting('atk_accel'))
    current_vec=add_vectors({current_vec,atk_accel_vec})
   end
      
   local tot_vec_x=current_vec.x+x_accel*acc
   local tot_vec_y=current_vec.y+y_accel*acc
   
   local max_speed_vec=make_vector(tot_vec_x,tot_vec_y,p.s:get_setting('max_speed'))
   p.dx=mid(-max_speed_vec.x,tot_vec_x,max_speed_vec.x)
   p.dy=mid(-max_speed_vec.y,tot_vec_y,max_speed_vec.y)

   p.x+=p.dx
   p.y+=p.dy
   p.x=mid(-4,p.x,96)
   p.y=mid(-4,p.y,96)   
 end,
 
 orient_players=function(self,p)
   local mov=p.i.movement
   local turn_speed=p.s:get_setting('turn_speed')
   if (mov.got_dir_input 
   and not mov.input_in_deadzone) then
    local turn_dir=sgn(fix_angle_diff(mov.a_input-p.ornt)) 
    p.ornt+=turn_speed*turn_dir
    p.ornt%=1
   end
   local max_turn_angle=p.s:get_setting('max_turn_angle')
   local ornt_op_diff=fix_angle_diff(p.ornt-self:get_other_player_dir(p))
   if abs(ornt_op_diff)>max_turn_angle then
    local over=abs(ornt_op_diff)-max_turn_angle
    local diff_dir=sgn(ornt_op_diff)
    p.ornt=mid(p.ornt,p.ornt-over*diff_dir,p.ornt-.1*diff_dir)%1
   end
 end,
 
 check_hits=function(self,p)
   local op=self:get_other_player(p)
   if self:should_check_parry(p,op) then
    local pry=self:check_hitbox(p,op,op.parrybox,true) 
    if pry then
     sfx(24,3)
     shake+=.25
     p.events.was_pry=true
     op.events.pry_succ=true
     local stance_diff=op.a.reversed and -.25 or .25
     make_sparks(pry.x,pry.y,op.ornt+stance_diff,op.a.reversed)
    end
   end
   if self:should_check_hits(p,op) then
    local hit=self:check_hitbox(p,op,op.hitbox,false)
    if hit then
     sfx(25,3)
     p.events.hit_succ=true
     op.events.was_hit=true
     local stance_diff=p.a.reversed and .25 or -.25
     op.injuries+=1
     local amt=op.injuries*op.injuries*4--==2 and 30 or 6
     local b_dir=p.s.state.name=='thr' 
      and self:get_other_player_dir(op)
      or p.ornt+stance_diff 
     make_blood(hit.x,hit.y,b_dir,amt,true)
     shake+=.5
     if op.injuries>2 then
      shake+=.5
      player_died+=1
      op.died=true
      wins[p.id]+=1
      sword_trails={}
     end
    end
   end
 end,

 should_check_hits=function(self,p,op)
  if (p.a.s_data[4]==1--.attack
  and not p.events.hit_succ
  and not p.events.was_pry
  and not op.died) then
   return true
  end
  return false
 end,
 
 should_check_parry=function(self,p,op)
  if p.a.a==animations.spr_atk
  or op.died then
   return false
  end
  if(p.a.s_data[4]==1--.attack
  and op.a.s_data[5]==1--.parry
  and (p.s.reversed~=op.s.reversed
  or p.a.a==animations.thr)) then
   return true
  end
  return false
 end,

 check_hitbox=function(self,op,p,hb,offset)
  local thrust=op.s.state.name=='thr'
  local cto,pt,ch=op.a.current_tip,op.a.prev_tip,op.a.current_handle
  local ct={x=cto.x,y=cto.y}
  local px,py,opx,opy=p.x+16,p.y+16,op.x+16,op.y+16
  local w2,h2=hb.w/2,hb.h/2
  if thrust then
   opx+=ch.x
   opy+=ch.y
   ct.x-=ch.x
   ct.y-=ch.y
  end
  local sa,ca=-p.cache.ca_ornt,p.cache.sa_ornt
  if(offset) then
	  local hor_axis=p.a.reversed and -1 or 1
	  px+=hor_axis*ca*hb.h_o+sa*hb.v_o
	  py+=hor_axis*sa*hb.h_o-ca*hb.v_o
	 end
  local radius=ct.x^2+ct.y^2
  local l_x,l_y=opx-px,opy-py
  local rot_l=rotate_coord(l_x,l_y,-sa,ca)  
  local r_rect_x=mid(-w2,rot_l.x,w2)
  local r_rect_y=mid(-h2,rot_l.y,h2)  
  local xdist=r_rect_x-rot_l.x
  local ydist=r_rect_y-rot_l.y
  if (xdist==0 and ydist==0) return {x=px,y=py}
  if (xdist^2+ydist^2>radius) return nil  
  local x_sgn=xdist==0 and 0 or sgn(xdist)
  local y_sgn=ydist==0 and 0 or sgn(ydist)
  local x_abs=sqrt(radius-ydist^2)*y_sgn
  local y_abs=sqrt(radius-xdist^2)*x_sgn
  local rp1={x=mid(-w2,rot_l.x+x_abs,w2),y=mid(-h2,rot_l.y-y_abs,h2)}
  local rp2={x=mid(-w2,rot_l.x-x_abs,w2),y=mid(-h2,rot_l.y+y_abs,h2)}  
  local p1=rotate_coord(rp1.x,rp1.y,sa,ca)
  local p2=rotate_coord(rp2.x,rp2.y,sa,ca)
  local t_a1,t_a2
  if thrust then
   ct.x+=ch.x
   ct.y+=ch.y
   t_a1=(atan2(ct.x-ch.x,ct.y-ch.y)-.005)--%1
   t_a2=(t_a1+.01)--%1
--   a1=atan2(p1.x-ch.x
  else
   t_a1=atan2(ct.x,ct.y)
   t_a2=atan2(pt.x,pt.y)
  end
  local a1=atan2(p1.x-l_x,p1.y-l_y)
  local a2=atan2(p2.x-l_x,p2.y-l_y) 
  local pnts_half=fix_angle_diff(a1-a2)*.5
  local swd_half=fix_angle_diff(t_a1-t_a2)*.5
  local dist=abs(fix_angle_diff((a2+pnts_half)-(t_a2+swd_half)))
  if dist<abs(pnts_half)+abs(swd_half) then
   if p.s.state.name=='pry' then
    local p_tip=p.a.current_tip
    return {x=p_tip.x+p.x+16,y=p_tip.y+p.y+16}
   else
    return {x=p.x+16,y=p.y+16}
   end
  end
  return nil   
 end, 

 update_states=function(self,p) 
   p.s:update(p.i.triggers,p.events,p.a.exp)   
   p.events.hit_succ=false
   p.events.was_hit=false
   p.events.pry_succ=false
   p.events.was_pry=false
 end,
 
 
 update_feet=function(self,p)
   if(rnd(10)<1) p.feet_jitter=(rnd(10)-5)*.002
   p.feet_a=fly_dir+p.feet_jitter
   if(in_tutorial)p.feet_h=0 
   local x0,y0=p.x+16,p.y+16
   local x_sprd,y_sprd=-p.cache.sa_ornt*feet.spacing,p.cache.ca_ornt*feet.spacing
   local x_trail,y_trail=cos(p.feet_a)*p.feet_h/2,sin(p.feet_a)*p.feet_h/2
   p.feet.l={x=(x0-x_trail)-x_sprd,y=(y0-y_trail)-y_sprd}
   p.feet.r={x=(x0-x_trail)+x_sprd,y=(y0-y_trail)+y_sprd}
 end,
 
 draw_feet=function(self,p)
    for _,f in pairs(p.feet) do
     rrect(f.x,f.y,feet.width,p.feet_h,p.feet_a,p.redbody and 8 or p.c,true,false)
    end
 end,
 
 
 draw_blades=function(self,p)
  if(g_sword.length==0)return
  local x0,y0=p.x+16,p.y+16
  local p1=bezier_point(p.a.b_bezier,0)
  local detail=g_sword.detail
  for i=0,detail do
   local p2=bezier_point(p.a.b_bezier,(1/detail)*i)
   local c=(i<=g_sword.h_length) and 2 or 7
   if (p.s.state.name~='pry' and p.s.state.name~='was_pry') or global_t%8<4 then
    line(p1.x+x0,p1.y+y0,p2.x+x0,p2.y+y0,c)
   end
   p1=p2
  end
 end,
 
 draw_players=function(self,p)
  local s=p.a.sprt
  local r=(p.s.reversed)
  if(s.r) r=not r
  local sx,sy=sunx,suny
  local t,inj=global_t,p.injuries
  local c=p.c
  p.redbody=false
  if inj>0 then
   local injfact=p.s.state.name=='was_hit' and 15 or inj==1 and fx.injury1_rate or fx.injury2_rate
   p.redbody=t%injfact<5 
   if(t%injfact==0)make_particles(p.x+16,p.y+16,3,0,360,3,false,3)
  end
  c=p.redbody and 8 or c
  rspr(s.num,p.cache.ca_ornt,p.cache.sa_ornt,p.x+16,p.y+16,2,r,c)--p.death_draw)
 end,
 
 draw_health=function(self,p)
  if(in_tutorial)return
  local x=p.id==1 and 1 or 83
  local y=min(0,global_t-310)
  for i=1,3-p.injuries do
  	spr(p.redbody and 92 or p.id+75,x+i*9,y)
 	end
 	x=p.id==1 and 1 or 120
 	local w=wins[p.id]
 	print(w,x+(w<10 and 2 or 0),y+1,6)
 end,
 
 get_other_player=function(self,p)
	 return self.players[p.id==1 and 2 or 1]
 end,

	get_other_player_dir=function(self,p)
  local op=self:get_other_player(p)
  return atan2(op.x-p.x,op.y-p.y)
 end,
 
 do_series=function(self,params)
  for f in all(params) do
   for p in all(self.players) do
    if(not p.died) f(self,p)-- or p.death_draw) f(self,p)
   end
  end
 end  
}

function rrect(px,py,w,h,a,c,border,trail)
 local dxcol,dycol=-sin(a),cos(a)
 local dxrow,dyrow=dycol,-dxcol
 local w2,h2=(w/2),(h/2)
 local init_x=-(dxrow*h2+dxcol*w2)
 local init_y=-(dyrow*h2+dycol*w2)
 for xi=0,w do
  local x,y=init_x,init_y
  for yi=0,h do
   if((border and (xi<2 or xi>w-1 or yi<2 or yi>h-1))) then
    local c1=c==8 and 8 or trail and c or 1
    pset(px+x,py+y,c1)
   else
    circfill(px+x,py+y,1,c)
   end
   x+=dxrow
   y+=dyrow   
  end
  init_x+=dxcol
  init_y+=dycol
 end
end

function rspr(s,ca,sa,px,py,w,r_y,clr)
 w*=4
 local dxcol,dycol=ca,sa--p.cache.ca_ornt,p.cache.sa_ornt
 local dxrow,dyrow=dycol,-dxcol
 local sx,sy=(s%16)*8,flr(s/16)*8
 local init_x=w-(w*dycol+w*dxcol)
 local init_y=w-(w*dyrow+w*dxrow)
 w*=2
 if(not r_y) then
  init_y=w-init_y
  dycol*=-1
  dyrow*=-1
 end
 for xi=0,w do
  local x,y=init_x,init_y
  for yi=0,w do
--   if band(bor(x,y),mask)==0 then
   if(x>1 and x<14 and y>1 and y<14) 
   or s==48 then
    local c=sget(sx+flr(x),sy+flr(y))
    if(c!=0) then
     	c=clr==8 and 8 or c==2 and clr or c
     	pset(px-(w/2)+xi,py-(w/2)+yi,c)
    end
   end
   x+=dxrow
   y+=dyrow
  end
  init_x+=dxcol
  init_y+=dycol
 end
 pal()
end


function make_vector(x,y,mag)
 local n_mag=pythag({x=x,y=y})
 local n_vec=(n_mag==0 and {x=0,y=0} or {x=x/n_mag,y=y/n_mag})  
 return mlt_vector(n_vec,mag)
end


function pythag(v)
 return sqrt(v.x^2+v.y^2)
end

function add_vectors(vecs)
 local t=nil
 for v in all(vecs) do
  t=t and {x=t.x+v.x,y=t.y+v.y} or v
 end
 return t
end

function sub_vectors(a,b)
 return{x=a.x-b.x,y=a.y-b.y}
end

function mlt_vector(v,f)
 return({x=v.x*f,y=v.y*f})
end



-->8
--anmtr

anmtr={
 init=function(a_name)
  o={
   a=nil,
   f=0,
   kf=0,
   s_data=nil,
   sprt=nil,
   exp=false,
   
   current_tip=nil,
   prev_tip=nil,
   current_handle=nil,
   
   current_coords=nil,
   
   h_bezier=nil,
   t_bezier=nil,
   b_bezier=nil,
   
   reversed=false,
   
   set_anim=function(self,a_name,reverse)
    self.a=animations[a_name]
    self.reversed=reverse
    self.f=0   
    self.kf=0
    self.exp=false
    self.sprt=sprites[self.a.sprites[self.f]] or self.sprt
    self:update_data()
   end,
   
   adv_frame=function(self)
    self.f+=1
    local a,f=self.a,self.f
    self.sprt=sprites[a.sprites[f]] or self.sprt
    if(self.a.static) then
     self.exp=false
    else
     self.exp=f==self.a.length-1
    end
    if(a.sword[f]~=nil) then
     self:update_data()
    end
   end,
   
   update_data=function(self)
    local f,r=self.f,self.reversed
    self.kf=f
    local new_s_data=self.a.sword[f] 
    if new_s_data[10]~=0 
    and global_t~=0 then
     sfx(new_s_data[10])
    end
    self.s_data=new_s_data
    self:update_curves()
   end,
   
   update_curves=function(self)
    local end_coords=get_sword_coords(self.s_data,self.reversed)
    local start_coords=self.current_coords or end_coords
    local c=ht_bezier_curves(start_coords,end_coords,self.s_data,self.reversed)
    self.h_bezier=c.h_bezier
    self.t_bezier=c.t_bezier
   end,
   
   get_t=function(self)
    if(self.a.static) return 1
    local nxt_kf=self.a.length
    for i=nxt_kf,self.kf+1,-1 do
     if(self.a.sword[i]) nxt_kf=i
    end
    return (1+self.f-self.kf)/(nxt_kf-self.kf)
   end,
   
   get_blade=function(self,sa,ca,curve,blade_reverse)
    local t=self:get_t()
    local h_p=bezier_point(self.h_bezier,t)--,sa,ca)
    local t_p=bezier_point(self.t_bezier,t)--,sa,ca)
    self.current_coords={
     s_x=h_p.x,
     s_y=h_p.y,
     e_x=t_p.x,
     e_y=t_p.y
    }
    local r_h_p=bezier_point(self.h_bezier,t,sa,ca)
    local r_t_p=bezier_point(self.t_bezier,t,sa,ca)
    self.prev_tip=self.current_tip or r_t_p
    self.current_tip=r_t_p
    self.current_handle=r_h_p
    local b_coords={
     s_x=r_h_p.x,
     s_y=r_h_p.y,
     e_x=r_t_p.x,
     e_y=r_t_p.y
    }
    local rev=not self.reversed
    if(blade_reverse)rev=not rev
    self.b_bezier=bezier_curve(b_coords,curve,rev)
   end,
  }
  
  o:set_anim(a_name,false)
  return o
  
 end
}


get_sword_coords=function(s_data,reverse)
 local h,v,a=s_data[1],s_data[2],s_data[3]
 if(reverse) then
  h=-h
  a=-a
 end
 local ax,ay
 s_x=h
 s_y=-v
 ax=sin(a)
 ay=cos(a)
 e_x=s_x+ax*g_sword.length
 e_y=s_y+ay*g_sword.length
 return{
  s_x=s_x,
  s_y=s_y,
  e_x=e_x,
  e_y=e_y
 }
end


function ht_bezier_curves(s_coords,e_coords,s_data,reverse)
 
 local h_coords={
  s_x=s_coords.s_x,
  s_y=s_coords.s_y,
  e_x=e_coords.s_x,
  e_y=e_coords.s_y
 }
 local t_coords={
  s_x=s_coords.e_x,
  s_y=s_coords.e_y,
  e_x=e_coords.e_x,
  e_y=e_coords.e_y
 }
 local h_curve=s_data[6]--.handle_curve or 0
 local t_curve=s_data[7]--.tip_curve or 0
 
 return{
  h_bezier=bezier_curve(h_coords,h_curve,reverse),
  t_bezier=bezier_curve(t_coords,t_curve,reverse)
 }
end

function bezier_curve(coords,h,reverse)
 if (reverse) h=-h
 local c=coords
 local dx,dy=c.e_x-c.s_x,c.e_y-c.s_y
 local a=atan2(dx,dy)
 local sa,ca=sin(a),cos(a)
 local nsa,nca=-sa,ca
 local xp=dx*nca-dy*nsa
 local c1xr=(xp/10)*3
 local c2xr=(xp/10)*7
 local cp1=rotate_coord(c1xr,h,sa,ca)
 local cp2=rotate_coord(c2xr,h,sa,ca)
 return{
  c1=c.s_x,
  v1=c.s_y,
  c2=cp1.x+c.s_x,
  v2=cp1.y+c.s_y,
  c3=cp2.x+c.s_x,
  v3=cp2.y+c.s_y,
  c4=c.e_x,
  v4=c.e_y
 }
end

function bezier_point(curve,t,r_sa,r_ca)
 local c=curve
 local x=(((1-t)^3)*c.c1)+(3*t*((1-t)^2)*c.c2)+(3*(t^2)*(1-t)*c.c3)+((t^3)*c.c4)
 local y=(((1-t)^3)*c.v1)+(3*t*((1-t)^2)*c.v2)+(3*(t^2)*(1-t)*c.v3)+((t^3)*c.v4)
 local coord={x=x,y=y}
 if(r_ca and r_sa) then
  coord=rotate_coord(coord.x,coord.y,r_sa,r_ca) 
 end
 return coord
end

function rotate_coord(x,y,sa,ca)
 local xr=ca*x-sa*y
 local yr=sa*x+ca*y
 return{x=xr,y=yr}
end
-->8
--state manager

state_manager={
 init=function(init_s)
  return {
   
   state=states[init_s],
   reversed=false,
   changed=false,
     
   update=function(self,i,e,exp)
    self.changed=false
    local event
    if force_event~=nil then
     event=force_event
    else 
     event=self.get_event(i,e,exp)
    end
    if(event=='exp' and self.state.stance_switch) then
     self.reversed=not self.reversed
    end
    local nxt_state=self.state.t[event]
    if(nxt_state~=nil) self:set_state(nxt_state)
   end,
   
   get_event=function(i,e,exp)
    if(e.was_pry) return 'was_pry'
    if(e.pry_succ) return 'pry_succ'
    if(e.was_hit) return 'was_hit'
    if(e.hit_succ) return 'hit_succ'
    if(exp) return 'exp'
    if(i.spr_atk) return 'spr_atk'
    if(i.atk2) return 'atk2'
    if(i.held_atk) return 'thr'
    if(i.atk) return 'atk'
    if(i.pry or i.held_pry) return 'pry'
    if(i.switch) return 'switch'
    return nil
   end,
   
   set_state=function(self,state_name)
    self.changed=true
    self.state=states[state_name]
   end,
   
   get_setting=function(self,name)
    if(self.state.settings) then
     return self.state.settings[name] or state_defaults[name]
    else
     return state_defaults[name]
    end
   end,
  }
 end
}


-->8
--sprite/animation/state data

function explode_s_data(obj)
 local retobj={}
 for k,s in pairs(obj) do
	 local obj,sprites,sword={},{},{}
--	 local sprites={}
--	 local sword={}
	 local lastpos,key,in_sword=1,nil,false
--	 local key=nil
--	 local in_sword=false
	 for i=1,#s do
	  if sub(s,i,i)=='|' then
	   local bit=sub(s,lastpos,i-1)
	   if bit=='#' then
	    in_sword=true
	   else
		   if(lastpos==1) then
		    if bit=='s' then
		     obj.static=true
		    else
		     obj.length=tonum(bit)
		    end
		   else
			   local head=sub(bit,1,1)
			   if head=='k' then
			    key=tonum(sub(bit,2,#bit))
			    if in_sword then
			     sword[key]={}
			    end
			   else
			    if in_sword then
					   add(sword[key],tonum(bit))
			    else
			     sprites[key]=bit
			    end
			   end
			  end
			 end
	   i+=1
	   lastpos=i
	  end
	 end
	 obj.sprites=sprites
	 obj.sword=sword
	 retobj[k]=obj
	end
	return retobj
end

function explode_st_data(obj)
 local retobj={}
 for k,s in pairs(obj) do
	 local obj,t,settings={},{},{}
	 local lastpos,key,in_settings=1,nil,false
	 for i=1,#s do
	  if sub(s,i,i)=='|' then
	   local bit=sub(s,lastpos,i-1)
	  	if lastpos==1 then
	  	 obj.stance_switch=bit=='1'
	  	elseif lastpos==3 then
	  	 obj.name=bit
	  	else 
	    local head=sub(bit,1,1)
		   if head=='#' then
		    in_settings=true
		   elseif head=='!' then
		    key=sub(bit,2,#bit)
		   else
		    if in_settings then
		     settings[key]=tonum(bit)
				  else
				   t[key]=bit
				  end
		   end
		  end
	   i+=1
	   lastpos=i
	  end
	 end
	 obj.t=t
	 obj.settings=settings
	 retobj[k]=obj
	end
 return retobj
end


sprites={
 intro={
  num=9,
  r=false
 },
 rdy={
  num=13,
  r=false
 },
 swing1={
  num=5,
  r=false
 },
 swing1_r={
  num=5,
  r=true
 },
 swing2={
  num=3,
  r=false
 },
 swing2_r={
  num=3,
  r=true
 },
 mid_swing={
  num=7,
  r=false
 },
 mid_swing_r={
  num=7,
  r=true
 },
 spr_swing={
  num=1,
  r=false
 },
 spr_swing_r={
  num=1,
  r=true
 }
}

animations=explode_s_data({
 intro='220|k0|intro|k170|swing1|k180|rdy|#|k0|6|2|.05|0|0|0|0|0|0|0|',
 rdy='s|k0|rdy|#|k0|6|2|.05|0|0|0|0|0|0|20|',
 switch='6|k0|intro|k2|swing1_r|k4|rdy|#|k0|-6|.75|-.05|0|0|0|0|0|0|0|',
 atk2_switch='12|k0|swing1|k11|rdy|#|k0|-6|-4|-.065|0|0|0|0|0|0|0|',
 atk_windup='42|k0|rdy|k4|swing2|k25|spr_swing|#|k0|6|.75|.05|0|0|0|0|0|0|61|k4|6|-1|.065|0|0|0|0|0|0|0|k10|4|-6|.23|0|0|-2|-3|0|0|0|k25|4|-6|.26|0|0|0|0|0|0|0|',
 atk2_windup='42|k0|rdy|k8|swing2|k16|spr_swing|#|k0|6|.75|.05|0|1|0|0|0|0|61|k2|6|-1|.065|0|0|0|0|0|0|0|k10|4|-6|.23|0|0|-2|-3|0|0|0|k25|4|-6|.26|0|0|0|0|0|0|0|',
 atk='46|k0|spr_swing|k2|swing2|k10|mid_swing|k14|swing2_r|k20|spr_swing_r|k38|swing2_r|k45|rdy|#|k0|4|-6|.25|0|0|0|0|0|0|22|k8|5|-3|.8|0|0|5|30|0|0|0|k16|0|5|.5|1|0|1|16|0|0|21|k22|-7|-3|.3|1|0|1|10|0|1|0|k28|-7|-3|.23|1|0|0|1|0|0|0|k42|-7|2|-.05|0|0|0|15|0|0|0|',
 thr_windup='44|k0|rdy|k4|swing1_r|k20|mid_swing|k30|spr_swing|#|k0|2|2|.5|0|0|0|0|0|0|61|k8|6|2|.5|0|0|0|0|0|0|0|k16|6|-7|.5|0|0|0|0|0|0|0|',
 thr='35|k0|mid_swing|#|k0|4|8.5|.5|1|0|0|0|1|0|22|k6|4|6|.5|1|0|0|0|0|0|27|k30|0|1|.05|0|0|0|0|0|0|0|k35|0|1|.05|0|0|0|0|0|0|0|',
 thr_fnt='32|k0|swing2|k14|spr_swing|#|k0|6|-4|.75|0|0|0|-10|0|0|0|k8|6|3|0|0|0|0|-10|0|0|0|k18|6|2|0|0|0|0|0|0|0|0|k20|6|2|.05|0|0|0|0|0|0|0|',
 thr_succ='30|k0|mid_swing|#|k0|6|2|.5|0|0|0|0|0|0|0|k24|6|2|.05|0|0|0|0|0|0|0',
 spr_atk='120|k0|spr_swing|k88|swing2|k90|mid_swing|k98|swing2_r|k110|spr_swing_r|k130|rdy|#|k0|6|-5|.2|0|0|0|-5|0|0|23|k8|5|-6|.28|0|0|0|0|0|0|0|k80|6|8|.75|0|0|5|15|1|0|0|k84|0|8|.5|1|0|1|10|0|0|62|k88|-6|0|.2|1|0|1|15|0|0|0|k94|-6|0|.1|1|0|0|0|0|0|0|k102|-6|0|.08|1|0|0|0|0|0|0|k110|-6|2|-.05|0|0|0|5|0|0|0|',
 fnt='34|k0|spr_swing|k10|swing2|k12|mid_swing|k26|swing2|k30|rdy|#|k0|6|-6.5|.065|0|0|0|5|0|0|0|k10|4|6|.8|0|0|0|7|0|0|0|k20|4|6|.82|0|0|0|0|0|0|0|k24|6|2|.05|0|0|0|-5|0|0|0|',
 pry='76|k0|mid_swing|k70|swing2|k80|spr_swing|k90|rdy|#|k0|5|3|.3|0|1|0|0|0|0|26|k1|5|3|.5|0|1|0|-7|0|0|0|k4|5|4|.75|0|1|-1|-5|0|0|0|k10|5|4|.85|0|0|0|0|0|0|0|k65|6|2|.05|0|0|0|-8|0|0|0|',
 was_hit='48|k0|rdy|#|k0|6|-2|.15|0|0|0|0|1|0|0|k8|6|2|.05|0|0|0|0|0|0|0',
 was_pry='64|k0|rdy|#|k0|6|0|.77|0|0|0|-10|0|0|0|k2|6|0|.8|0|0|0|0|0|0|0|k60|6|2|.05|0|0|0|-5|0|0|0|',
 hit_succ='26|k0|mid_swing_r|k2|swing2_r|k8|spr_swing_r|#|k0|-6|0|.28|0|0|0|10|0|0|0|k2|-6|0|.23|0|0|0|0|0|0|0|k15|-6|0|.23|0|0|0|0|0|0|0|k20|-6|2|.05|0|0|0|0|0|0|0|',
 pry_succ='32|k0|mid_swing_r|k4|swing2|k8|spr_swing|k16|rdy|#|k0|9|0|.6|0|0|0|0|0|0|0|k2|9|0|.77|0|0|0|-5|0|0|0|k12|9|0|.77|0|0|0|0|0|0|0|k28|8|2|.05|0|0|0|-15|0|0|0|',
})


states=explode_st_data({
 intro='0|intro|!exp|rdy|',
 rdy='0|rdy|!atk|atk_windup|!atk2|atk_windup|!thr|thr_windup|!spr_atk|spr_atk|!pry|pry|!switch|switch|!was_hit|was_hit|',
	switch='1|switch|!was_hit|was_hit|!exp|rdy|',
 atk_windup='0|atk_windup|!atk2|atk2_switch|!thr|thr_windup|!spr_atk|spr_atk|!pry|pry|!atk|fnt|!was_hit|was_hit|!exp|atk|#|!max_speed|.5|!accel|.2|!turn_speed|.005|!max_turn_angle|.3|!deadzone_width|0',
 thr_windup='0|thr_windup|!thr2|atk2_switch|!atk|thr_fnt|!exp|thr|!atk2|atk2_switch|!was_hit|was_hit|!pry|pry|!thr|thr_fnt|#|!turn_speed|0.002|!max_speed|0|!accel|0|!max_turn_angle|0.5|!deadzone_width|0|',
 atk2_switch='1|atk2_switch|!exp|atk2_windup|#|!max_speed|0.3|!turn_speed|0.005|!accel|0.1|',
 atk2_windup='0|atk2_windup|!exp|atk|!was_hit|was_hit|!spr_atk|spr_atk|!pry|pry|!atk|fnt|#|!turn_speed|0.005|!max_speed|0.5|!accel|0.2|!max_turn_angle|0.3|!deadzone_width|0|',
 atk='1|atk|!was_hit|was_hit|!was_pry|was_pry|!hit_succ|hit_succ|!exp|rdy|#|!max_speed|.3|!accel|.1|!turn_speed|.001|!max_turn_angle|.3|!deadzone_width|0|',
 thr='0|thr|!exp|rdy|!was_hit|was_hit|!was_pry|was_pry|!hit_succ|thr_succ|#|!atk_accel|0.38|!accel|0|!max_speed|3.5|!turn_speed|0.001|!max_turn_angle|0.5|',
 spr_atk='1|spr_atk|!exp|rdy|!hit_succ|hit_succ|!was_hit|was_hit|#|!max_speed|4|!turn_speed|0.0025|!max_turn_angle|1|!deadzone_width|0|!atk_accel|0.7|!accel|0|',
 fnt='0|fnt|!exp|rdy|!was_hit|was_hit|#|!accel|0.1|!turn_speed|0.005|!max_speed|0.3|',
 thr_fnt='0|thr_fnt|!was_hit|was_hit|!exp|rdy|#|!accel|0.1|!turn_speed|0.005|!max_speed|0.4|',
 pry='0|pry|!pry_succ|pry_succ|!was_hit|was_hit|!exp|rdy|#|!turn_speed|0.02|!accel|0.2|!max_speed|.5|',
 pry_succ='0|pry_succ|!was_hit|was_hit|!exp|rdy|',
 was_pry='0|was_pry|!exp|rdy|!was_hit|was_hit|#|!max_speed|0.3|!accel|0.1|!turn_speed|0.005|',
 was_hit='0|was_hit|!was_hit|was_hit|!exp|rdy|#|!max_speed|2|!accel|.1|!atk_accel|-50|!turn_speed|.005|',
 hit_succ='1|hit_succ|!was_hit|was_hit|!exp|rdy|#|!max_turn_angle|.417|',
 thr_succ='0|thr_succ|!was_hit|was_hit|!exp|rdy|'
})





-->8
--stars/particles

--------------
--star stuff
--------------

stars={}

nxt_fly_dir=rnd(1)
fly_dir=nxt_fly_dir

function random_fly_dir()
 if flr(rnd(120))==1 then
  nxt_fly_dir=rnd(1)
 end
end

function init_generate_stars()
 stars={}
 for i=0,120 do
  local x=rnd(170)-50
  local y=rnd(170)-50  
  add_star(x,y)
 end
end 

function add_star(x,y)
	local d=rnd(1000)
 local plnt=rnd(10)<1 and 2 or 1
	add(stars,{
	 x=x,
	 y=y,
	 d=d,
	 spn=0,
	 sz=flr((1.1-(d/1000))*1.5 * plnt)
	})
end
 
function update_stars()
 fly_dir+=(nxt_fly_dir-fly_dir)*fx.star_turn_speed
 local cs=cos(fly_dir)
 local sn=sin(fly_dir)
 if #stars < 150 and rnd(4)<2 then
  local off=rnd(181)-90.5
  local x=64+(91*cs)-off*sn--((rnd(181)-90.5)*sn)
  local y=64+(91*sn)+off*cs--+((rnd(181)-90.5)*cs)
  add_star(x,y)
 end
 local spd=fx.star_speed
 for s in all(stars) do
   s.x-=cs*(spd/s.d)
   s.y-=sn*(spd/s.d)
  if(s.spn==28) then 
   make_particles(s.x,s.y,1,-fly_dir+.25,0,0,true,2) 
  end
  if(s.spn==1) then
   del(stars,s)
  end
  if(s.spn>0) then
   s.spn-=1
  end
  if s.x>215 or s.x<-88 or s.y>214 or s.y<-88 then
   del(stars,s)
  end
 end
end

function draw_starz()
-- print(band(bor(-100,-100),0xff00)~=0)
 for s in all(stars) do
  if s.spn>0 then
   if s.spn < 30 then
	    circfill(s.x,s.y,flr((30-s.spn)/5),2)
	    circfill(s.x+rnd(2)-1,s.y+rnd(2)-1,min((10-s.spn),6),0)
	  else 
	   local r=s.spn%8
	   if r<5 then
	    circfill(s.x,s.y,s.sz,6)
	   end
	  end
  else
   circfill(s.x,s.y,s.sz,15)
  end
 end
end


----------------
--particle stuff
----------------

particles={}
erasers={}


function make_sparks(x,y,a,stance)
 make_particles(x,y,5,-(a-.25),100,4,true,7)
end

function make_blood(x,y,a,amt,od)
 make_particles(x,y,amt,-(a-.25),90,5,od,3)
end


function make_stars(prob)
 if (in_intro or #particles<fx.max_particles) and global_t%prob==0 then
	  local r=flr(rnd(#stars)+1)
	  local s=stars[r]
	  if(s.spn==0)then
	   s.spn+=90
	  end
 end
end



--xpos,ypos,number,angle,spread,
--velocity,one direction,
--colorchart
function make_particles(x,y,n,a,s,v,od,cc)
 srand(global_t)
 local sa=sin(a)
 local ca=cos(a)
 s=od and s or 360
 for i=0,n-1 do
  local dv=(od and v/2 or -v/4)
  local vel=rnd(v/2)+dv
  local p={
   x=x-64,
   y=y-64,
   dx=(sa+(rnd(s)-s/2)*.01)*vel,
   dy=(ca+(rnd(s)-s/2)*.01)*vel,
   t=0,
   size=1,
   c=cc,--[0],
   eraser=false
  }
  local e={
   x=p.x,
   y=p.y,
   dx=p.dx,
   dy=p.dy,
   t=0,
   size=1,
   c=0,
   eraser=true
  }
  add(particles,p)
  add(erasers,{p=e,t=20})
 end
end

function make_erasers()
 for e in all(erasers) do
  if e.t==0 then
   add(particles,e.p)
   del(erasers,e)
  else
   e.t-=1
  end
 end
end

function new_update_particles()
 for i=1,#particles-fx.max_particles do
  del(particles,particles[1])
 end
 for p in all(particles) do
  local speed=fx.orbit_speed
  local blend=fx.blend_rate
  local gravity=fx.gravity
  local cx=p.x
  local cy=p.y
  local a=-atan2(cx,cy)
  local dist=pythag({x=cx,y=cy})
  if dist<fx.p_dist_size_change
  and p.t>30 then 
   p.size=0
  end
  local sa=sin(a)
  local ca=cos(a)
  local dx=sa*speed+ca*(gravity/dist)
  local dy=ca*speed-sa*(gravity/dist)
  p.dx+=(dx-p.dx)*blend
  p.dy+=(dy-p.dy)*blend
  p.x+=p.dx
  p.y+=p.dy
  p.t+=1
  if p.t>10 and dist<fx.min_core_dist then
   del(particles,p)
  end
 end
end


function draw_stars()
 for p in all(particles) do
  if(not p.eraser) then
   minskycirc(p.x+sunx,p.y+suny,p.size,p.c)
  else
   eraser_rect(p.x+sunx,p.y+suny)
  end
 end
end

----------------------
--sun stuff
----------------------
sunx=64
suny=64

sun={
 rate=10,
 x_off=0,
 y_off=0,
 scale=0,
 min_scale=3,
 max_scale=4,
 v=6,--volatility
 max_dist=1
}

sun_s={
 rate=5,
 x_off=0,
 y_off=0,
 scale=0,
 min_scale=3,
 max_scale=5,
 v=16,--volatility
 max_dist=1
}

function update_sun()
 rnd_sun(sun)
 rnd_sun(sun_s)
end

function rnd_sun(s)
 if global_t%s.rate==0 then
  srand(global_t)
  s.x_off+=((rnd(s.v)+1)*.5)-s.v/4
  s.y_off+=((rnd(s.v)+1)*.5)-s.v/4
  s.scale+=((rnd(s.v)+1)*.25)-s.v/8
  s.x_off=mid(-s.max_dist,s.x_off,s.max_dist)
  s.y_off=mid(-s.max_dist,s.y_off,s.max_dist)
  s.scale=mid(s.min_scale,s.scale,s.max_scale)
 end
end

function draw_sun_shadow()
 if(sun_s.scale==0)return
 local x,y=sunx+sun_s.x_off,suny+sun_s.y_off
 minskycirc(x,y,sun_s.scale,1)
 minskycirc(x,y,sun_s.scale-1,1)
 minskycirc(x,y,sun_s.scale-2,1)
end

function draw_sun()
 if(sun.scale==0)return
 local x,y=sunx+sun.x_off,suny+sun.y_off
 circfill(x,y,sun.scale,3)
 circ(x,y,sun.scale,2)
end


----------------
--other stuff
----------------

function minskycirc(x,y,r,c)
 if (band(bor(x,y),0xff80)!=0) return 
 x,y=x+0.5,y+0.5
 local j,k,rat=r,0,1/r
 poke(0x5f25,c) --set color
 for i=1,0.785*r do
  k-=rat*j
  j+=rat*k
  sset(x+j,y+k)
  sset(x+j,y-k)
  sset(x-j,y+k)
  sset(x-j,y-k)
  sset(x+k,y+j)
  sset(x+k,y-j)
  sset(x-k,y+j)
  sset(x-k,y-j)
 end
 sset(x,y-r)
 sset(x,y+r)
 sset(x-r,y)
 sset(x+r,y)
 sset(x,y)
end


trails={}

function eraser_rect(x,y)
 for pxl in all(trails[1]) do
  sset(pxl.x,pxl.y,0)
 end
 if #trails>40 then 
  del(trails,trails[1])
 end
 local set={}
 for xi=-2, 2 do
  for yi=-2, 2 do
   local posx=x+xi
   local posy=y+yi
   if sget(posx,posy)~=0 then
    sset(posx,posy,5)
    add(set,{x=posx,y=posy,t=global_t})
   end
  end
 end
 add(trails,set)
end


function draw_background()
 memcpy(0x6000, 0x0000, 0x2000)
end

function screen_dither()
 srand(global_t)
 for i=0,600 do
  sset(rnd(128),rnd(128),0)
 end
end
-->8
--input manager

input_manager={
 init=function()
  return {

	  atk_held=0,
	  pry_held=0,
	  dir_held=0,
	  
	  last_inp_dir=nil,
	  
	  held_atk_threshold=12,
	  held_pry_threshold=4,
	  
	  switch_threshold=3,
	  switch_buffer=3,
	  
	  movement={
--	   x_input=0,
--		  y_input=0,
--		  got_dir_input=false,
--		  a_input=0,
--		  input_in_deadzone=false
	  },
	  
	  triggers={
--	   atk=false,
--	   atk2=false,
--	   held_atk=false,
--	   spr_atk=false,
--	   pry=false,
--	   switch=false
			},
	  
	  update=function(self,p,op_dir)
	   if(in_tutorial)return-- or globals.t<8) return
	   local triggers={}
	   local movement={}
	   local p_id=p.id-1
	   local ornt=p.ornt
	   local stance=p.s.reversed and 1 or -1
	   local a_frame=p.a.f
	   local deadzone_width=p.s:get_setting('deadzone_width')
	   local fb_deadzone_width=p.s:get_setting('fb_deadzone_width')
	   local side_thresh=fb_deadzone_width/2
	 
	   local r=btn(0,p_id) and -1 or 0
	   local l=btn(1,p_id) and 1 or 0
	   local u=btn(2,p_id) and -1 or 0
	   local d=btn(3,p_id) and 1 or 0
	   local x_input,y_input=l+r,u+d
	   movement.x_input=x_input
	   movement.y_input=y_input
	   movement.a_input=atan2(x_input,y_input)
	   movement.got_dir_input=(abs(x_input)+abs(y_input)!=0)
	   
	   local atk_dwn=btn(4,p_id)
	   local pry_dwn=btn(5,p_id)
	   
	   if movement.got_dir_input
	   or atk_dwn
	   or pry_dwn then
	    last_inp_t=global_t
	   end
	   
	   triggers.spr_atk=atk_dwn and pry_dwn
	  
	   local held_atk_f=self.atk_held==self.held_atk_threshold
	   local atk_f=self.atk_held>0 and self.atk_held<self.held_atk_threshold
	   triggers.held_atk=atk_dwn and held_atk_f
	   triggers.atk=not atk_dwn and atk_f
	   self.atk_held=atk_dwn and self.atk_held+1 or 0
	   
	   local held_pry_f=self.pry_held==self.held_pry_threshold
	   local pry_f=self.pry_held>0 and self.pry_held<self.held_pry_threshold
	   local held_pry=pry_dwn and held_pry_f
	   local pry=not pry_dwn and pry_f
	   triggers.pry=pry or held_pry
	   self.pry_held=pry_dwn and self.pry_held+1 or 0

	   
	   local inp_ornt_diff=fix_angle_diff(movement.a_input-ornt)
	   movement.input_in_deadzone=abs(inp_ornt_diff)<deadzone_width/2
	   
	   local inp_op_diff=fix_angle_diff(movement.a_input-op_dir)    
	   local inp_dir=sgn(inp_op_diff)
	   if (not movement.got_dir_input) then
	    inp_op_diff=0
	    inp_dir=0
	   end
	   triggers.atk2=false
	   if (mid(side_thresh,abs(inp_op_diff),.5-side_thresh)==abs(inp_op_diff)) then
	    --got sideways input
	    if sgn(inp_op_diff)~=stance then
	     triggers.atk2=triggers.atk
	    end
	    
	    if(inp_dir==self.last_inp_dir
	    and a_frame>self.switch_buffer) then
	     self.dir_held+=1
	    else
	     self.dir_held=0
	    end
	    self.last_inp_dir=inp_dir
	   else
	    self.dir_held=0
	   end
	   triggers.switch=movement.got_dir_input 
	    and self.dir_held>self.switch_threshold 
	    and inp_dir~=stance
	   self.triggers=triggers
	   self.movement=movement
	  end
	 }
 end
}

function fix_angle_diff(a)
 if(abs(a)>.5) then
  a=(1-abs(a))*-sgn(a)
 end
 return a
end

-->8
--other fx

sword_shadows={}

sword_trails={}

function new_draw_sword_trails()
 for p in all (player_manager.players) do
  if(p.a.s_data[4]==1) then --.attack) then
	  local ct,pt=p.a.current_tip,p.a.prev_tip
	  local diff_vec=sub_vectors(pt,ct)
	  local dist=pythag(diff_vec)
--	  if(dist>0) then
		  local length=fx.trail_length
		  dist*=length
		  local bits=fx.trail_bits*dist
		  local trail_a
		  if p.s.state.name=='thr' then
		   trail_a=atan2(sub_vectors(p.a.current_handle,ct))+p.ornt+.25
		  else
		   trail_a=atan2(diff_vec.x,diff_vec.y)-(p.a.reversed and -.015 or .015) 
		  end
		  local sa,ca=sin(trail_a),cos(trail_a)
		  local c=get_sword_color(p)
		  local px,py=p.x+16,p.y+16
		  for i=1,bits do
		   local x=px+ct.x+ca*dist*i
		   local y=py+ct.y+sa*dist*i
		   add(sword_trails,{
		    x=x,
		    y=y,
		    t=global_t,
		    a=trail_a,
--		    spwn=false,
		    c=c
		   })
		  end
		  local r=flr(rnd(3))
		  if(p.atk_part < 3 and p.s.state.name ~='thr' and r==0) then 
		   p.atk_part+=1
		   make_particles(px+ct.x,py+ct.y,1,-trail_a+(p.reversed and -.25 or .25),0,5,true,c)
		  end		  
--	  end
  end
 end
 for trl in all(sword_trails) do
		local sz=fx.trail_life-(global_t-trl.t);
	 if(sz<=0) then
		 del(sword_trails,trl)
		else
		 sz*=fx.trail_size
--		 printh(sz)
		 rrect(trl.x,trl.y,sz,sz,trl.a,trl.c,false,true) 
--		 rrect(trl.x,trl.y,sz,sz,1,trl.c,false,true) 
--	  printh(trl.x) 
	end
	end
end

function add_sword_shadows()
 for p in all(player_manager.players) do 
  if (p.died) return
  if (in_tutorial and p.id==2) return
	 if ((p.s.state==states.rdy 
	 or p.s.state==states.atk2_windup) 
	 and p.a.f==0) 
	 or (p.s.state==states.spr_atk 
	 and p.a.f==10) then 
	  local s_s={
	   life=fx.shadow_life,
	   c=get_sword_color(p),
	   p=p
	  }
	  add(sword_shadows,s_s)
	 end
	end
end


function new_draw_sword_shadows()
 for s in all(sword_shadows) do
  local p=s.p
  local sa,ca=p.cache.ca_ornt,-p.cache.sa_ornt
  local h_p=p.a.current_handle
  local t_p=p.a.current_tip
  local x0,y0=p.x+16,p.y+16
  local ml2=fx.shadow_life/2
  local fact=(ml2-abs(ml2-s.life))/ml2
  local dist=fact*fx.shadow_dist
  local stance=(p.a.reversed and -1 or 1)
  if(p.s.state.name=='spr_atk') then
   local v=sa
   sa=-ca*-stance
   ca=v*-stance
  end
  for i=1,fx.shadow_num do
   local i_dist=i*dist*stance
   local dx,dy=ca*i_dist+x0,sa*i_dist+y0  
   line(h_p.x+dx,h_p.y+dy,t_p.x+dx,t_p.y+dy,s.c)
  end
  s.life-=1
  if (s.life<=0) del(sword_shadows,s)
 end
end


function get_sword_color(p)
 if(p.s.state==states.spr_atk) return 14
 local c=p.a.reversed and 9 or 12
 if(p.id==2)c=c==9 and 12 or 9
 return c
end

p_trails={}

function add_parry_trails()
 for p in all(player_manager.players) do
  if p.s.state.name=='pry'
  and p.a.f<10 then
   local x0,y0=p.x+16,p.y+16
   add(p_trails,{
    x1=x0+p.a.current_handle.x,
    y1=y0+p.a.current_handle.y,
    x2=x0+p.a.current_tip.x,
    y2=y0+p.a.current_tip.y,
    l=4,
    c=get_sword_color(p)
   })
  end
 end
end

function draw_parry_trails()
 for trl in all(p_trails) do
  line(trl.x1,trl.y1,trl.x2,trl.y2,trl.c)
  trl.l-=1
  if trl.l<=0 then
   del(p_trails,trl)
  end
 end
end


function letterbox()
 if(letter_h<=0)return
 sspr(0,48,128,16,0,128-letter_h,128,letter_h)
 sspr(0,48,128,16,0,0,128,letter_h,false,true)
end

function draw_fight()
 if global_t%5<4 then
		spr(32,30,30,6,2)
 	spr(64,78,30,6,2)
 end
end

function draw_ded()
	spr(38,1,36,10,2)
	spr(70,81,36,6,2)
end

function draw_instr()
 print("🅾️: rematch",12,82,7)
 print("❎: menu",76,82,7)
end

shake=0

function do_shake()
 local x=6-rnd(12)
 local y=6-rnd(12)
 x*=shake
 y*=shake
 camera(x,y)
 shake*=.95
 if(shake<.05)shake=0
 if(shake==0)camera(0,0)
end
-->8
--intro

c_up=true

function menu_intro_update()
 global_t+=1
 t=global_t
 letter_h=min(20,(t-1250)*.5)
 update_stars()
 new_update_particles()
 if t==180 then 
  shake+=.5
  sfx(58)
 end
 if t>180 then
  update_sun()
  make_stars(t>1250 and 1 or flr(4*(1250/t)))
  make_erasers()
 end
 if (t>1630) shake+=.06
 if t>1720 
 or btnp(4,0)
 or btnp(4,1) then
  global_t=0
  shake=0
  reload()
  music(48)
  init_generate_stars()
  in_intro=false
  _update60=menu_update
  _draw=menu_draw  
 end
end


intro_x=-1

function menu_intro_draw()
 cls()
 do_shake()
 t=global_t
 setpal()
 if (t<15) return
 if (t<22) fadepal()
 do_background()
 draw_sun()
 draw_starz() 
 letterbox()
 if t<1600 then
	 if t>1250 then
	  if t>1310 then    
	   print("and sating the void",4,80,6)
	   if (t>1430)print(" with blood",80,80,8)
	  end
	 else
	  if t>750 then
	   print("two gods battle",33,93,6)
	   if(t>1000) print("wielding cosmic blades",20,105,6)
	  else
	   if t>250 and t<740 then
	    print("at the end of time and space",8,20,6)
	    if(t>500)print("as the crimson eye devours all",4,32,6)--"a god's blood must sate the void-",0,96,6)
    end
   end
  end
 end
 if(t>1650) then
  cls(7)
  if (t%3<2) then
   circfill(64,64,35,3)
   circfill(64,64,t-1635,0)
  end
 else
  intro_x=(t-1360)*.22
    circfill(intro_x,64,1,10)
    circfill(131-intro_x,64,1,6)
 end
 if(t>1660)cls()
end
-->8
--menu screen

function menu_update()
 global_t+=1
 check_no_inp(7200)
 update_stars()
 if(global_t<30)return
 if btnp(2,0) 
 or btnp(3,0)
 or btnp(2,1)
 or btnp(3,1) then
  last_inp_t=global_t
  c_up=not c_up
  sfx(20)
 end
 if btnp(4,0)
 or btnp(4,1) then
  if c_up then
   _update60=fadefunc
   particles={}
   game_init()
   music(0)  
   _update60=game_intro_update
   _draw=game_draw
   cls(7)
   sfx(24)
  else
   init_tut()
   _update60=tutorial_update
   _draw=tutorial_draw
  end
 end
end

function menu_draw()
 cls()
 do_shake()
 if(global_t<5) return
 setpal()
 draw_starz()
 spr(128,10,16,14,8)
 if(global_t<10) fadepal()
 if(global_t<30) return
 print("fight",50,91,3)
 print("fight",49,90,7)
 print("tutorial",50,101,3)
 print("tutorial",49,100,7)
 spr(143,40,c_up and 89 or 99) 
end


-->8
--tutorial

function init_tut()
 global_t=0
 current_page=1
 in_tutorial=true
 player_manager:make_player(1,48,16,0,'rdy',10)
 player_manager:make_player(2,150,16,.75,'rdy',14)
end


function tutorial_update()
 global_t+=1
 check_no_inp(3600)
 if btnp(4,0)
 or btnp(4,1) then
  last_inp_t=global_t
  if current_page<#pages then
	  current_page+=1
	 else
	  global_t=1
	  in_tutorial=false
   player_manager:clear_players()
	  _update60=menu_update
	  _draw=menu_draw
	  force_event=nil
	 end
 end
 local intv=(current_page==3 or current_page==7) and 30 or 70
 force_event=global_t%intv==0 and demos[current_page] or nil
 player_manager:update()
 add_sword_shadows()
 add_parry_trails()
 update_stars()
end

function tutorial_draw()
 cls()
 draw_starz()
 if(global_t==0)return
 new_draw_sword_trails()
 new_draw_sword_shadows()
 draw_parry_trails()
 player_manager:draw()
-- local h=#pages[current_page]*6
-- rectfill(9,60,122,62+h,0)
 cursor(10,62,7)
 foreach(pages[current_page], print) 
 setpal()
end

demos={
 'switch',
 'atk',
 'atk2',
 'pry',
 'spr_atk',
 'thr',
 'atk',
}

--current_page=1

pages={
 {
  '●use ⬆️⬇️⬅️➡️ to move',
  '',
  '●moving left or right', 
  '  relative to your opponent',
  '  will switch your',
  '  sword stance'
 },
 {
  '●tap and release 🅾️ to',
  '  perform a swing attack',
  '',
  "●don't button mash!",
  ''
 },
 {
  '●swing attacks can be',
  '  cancelled into the',
  '  opposite direction by',
  '  pressing 🅾️ plus the ',
  '  second direction' 
 },
 {
  '●press ❎ to parry',
  '',
  '●parries must match the', 
  '  stance of an incoming',
  '  attack in order to', 
  '  block it'
 },
 {
  '●press 🅾️+❎ to perform',
  '  a super attack',
  '',
  '●super attacks are slow',
  '  but unblockable'
 },
 {
  '●hold 🅾️ to perform',
  '  a thrust attack',
  '',
  '●thrust attacks can be', 
  '  parried from either stance' 
 },
 {
  '●press 🅾️ again early in an',
  '  attack animation to feint',
  '',
  '●try to trick your opponent',
  '  into parrying!',
  '',
  "●button mashing will result",
  "  in feinting instead of",
  "  attacking :("
 } 
}

-->8
--game intro

function game_init()
 cls()
 particles={}
 sword_trails={}
 player_died=0
 global_t=0
 clear_background()
 player_manager:clear_players()
 local cs,sn=cos(fly_dir),sin(fly_dir)
 local x,y=48-(240*cs),48-(240*sn)
 g_sword.length=0
 player_manager:make_player(1,x-8*cs,y,.25,'intro',10)
 player_manager:make_player(2,x+8*cs,y,.50,'intro',6)
end


function game_intro_update()
 global_t+=1
 local t=global_t
 fx.star_speed=min(max(10,fx.full_star_speed*(global_t/100)),fx.full_star_speed)
 letter_h=min(16,t-10)
 if t>60 then
  local xs={24,72}
  foreach(player_manager.players,
   function(p)
	   p.x+=(xs[p.id]-p.x)*.03
	   p.y+=(48-p.y)*.03
	   p.a:update_curves()
	  end) 
	end
	if (t==180)sfx(28) 
	if t>180 and t<220 then
	 local length_f=((40-(220-t))/40)
	 g_sword.length=g_sword.full_length*length_f
	 g_sword.h_length=g_sword.full_h_length*length_f
	end
 player_manager:update()
 update_stars()
 update_sun()
 new_update_particles()
 make_erasers()
 add_sword_shadows()
 if (t==220) sfx(29)
 if t==270 then
  g_draw_fight=true
  sfx(19)
 end
 if t>270 then
  letter_h=min(16,(300-t)*2)
 end
 if t==300 then
  g_draw_fight=false
  for p in all(player_manager.players) do
   p.input_disabled=false
  end
  _update60=game_update
  return
 end
end
__gfx__
00000000000000000000000ee00000000000000ee00000000000000ee00000000000000ee00000000000000ee00000000000000ee00000000000000e00000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000011110000000001111110000000000000111100000000011110000000000000000000000000000000000000000022000
00077000000000000011100000000000122211000000011222211000000000001222110000000112210000000000000011110000000000011111000000288200
00077000000001111112110000000001112221000000012222221100000000011122210000000122210000000000000112211000000000012221100066666666
00700700000001122112210000000011211221000000011111122100000000112112210000000111110000000000001122221100000001111122100000288200
00000000000111222212210000000112281221000000011288122100000001122812210000000112880000000000011288122100000001128812100000022000
00000000001121822812210000000122228221000000012221121100000001222282210000000122210000000000012221122100000001222112100000000000
00000000001221811812210000001118211221000000012221111000000011182112210000000122210000000000012221122100000001222112100000000000
00000000001221001122210000011211812221000000011288000000000112118112210000000112880000000000011288122100000001128812100000000000
00000000001221111222110000012221122211000000011111000000000122211112210000000111110000000000011111221000000011111122100000000000
00000000001221222221100000012221222110000000012221000000000122222222110000000122210000000000012221221000000012211221100000000000
00000000001222222211000000011222221100000000011221000000000112222221100000000112210000000000011212211000000012212211000000000000
00000000001111111110000000001111111000000000001111000000000011111111000000000011110000000000001111110000000011111110000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000e00000000000000ee00000000000000ee00000000000000000000000000000ee00000000000000ee000000000000000ee00000000000000e00000000
00000000000000000000000000000000000000000000000000044444444448000044444444444480000480000000004800004444444444800004800000004800
00000000000000000000000000000000000000000000000000444444444488000444444444444480004448000000044800044444444448800044800000044800
00044444480000444444480000444444448000048000004804444444444880004444444444444480044444800000444800444444444488000444800000444800
00444444880004444444880004444444488000448000044804444488888800004444488888844480044444480000444800444488888880000444800000444800
04444448800044444448800044444444880004448000444804444880000000004444880000044480044444448000444800444880000000000444800000444800
04448888000088844488000044448888800004448000444804448800000000004448800000044480044444444800444800444444444444800444800000444800
04440000000000044480000044488000000004448000444804448000000000004448000000044480044484444480444800444444444444800444800000444800
04444444480000044480000044480000000004444444444804448000000000004448000000044480044488444448444800444444444444800444800000444800
04444444880000044480000044480000000004444444444804448000000000004448000000044480044480844444444800888888888444800444800000444800
04444448800000044480000044480000048004444444444804448000000000004448000000444480044480084444444800000000000444800444800000444800
04448888000000044480000044480000448004448888444804448000000000004448000004444480044480008444444800000000000444800444800000444800
04448000000000444444480044444444448004448000444804444444444448004444444444444480044480000844444800004444444444800444444444444800
04488000000004444444880044444444488004488000448804444444444488004444444444444880044880000084448800044444444448800444444444448800
04880000000044444448800044444444880004880000488004444444444880004444444444448800048800000008488000444444444488000444444444488000
08800000000088888888000088888888800008800000880008888888888800008888888888888000088000000000880000888888888880000888888888880000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000448000000444480000444444444480000444444444480011111111111111117777777777777777
0000000000000000000000000000000000000000000000000444480000444448000444444444488000444444444448001aa11aa1166116617777777777777777
0000444444444448000480000000000000000000000000004444448004444448004444444444880004444444444448001aaaaaa1166666617777777777777777
0004444444444488004480000000000000000000000000004444444444444448004448888888800004448888844448001aaaaaa1166666617777777777777777
00444444444448800444800000000000000000000000000044444444444444480044480000000000044480000444480011aaaa11116666117777777777777777
008888844488880004448000000000000000000000000000444484444484444800444800000000000444800008444800011aa110011661107777777777777777
00000004448000000444800000000000000000000000000044448844488444480044444444448000044480000044480000111100001111007777777777777777
00000004448000000444800000000000000000000000000044448088880444480044444444488000044480000044480000011000000110007777777777777777
00000004448000000448800000000000000000000000000044448000000444480044488888880000044480000044480011111111000000007777777777777777
00000004448000000488000000000000000000000000000044448000000444480044480000000000044480000444480018811881000000007777777777777777
00000004448000000880000000000000000000000000000044448000000444480044480000000000044480000444480018888881000000007777777777777777
00000004448000000004800000000000000000000000000044448000000444480044444444444480044444444444480018888881000000007777777777777777
00000004488000000048800000000000000000000000000044488000000444880044444444444880044444444444880011888811000000007777777777777777
00000004880000000488000000000000000000000000000044880000000448800044444444448800044444444448800001188110000000007777777777777777
00000008800000000880000000000000000000000000000088800000000888000088888888888000088888888888000000111100000000007777777777777777
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000007777777777777777
00002000000020000000200000002000000020000000200000002000000020000000200000002000000020000000200000002000000020000000200000002000
20000000200000002000000020000000200000002000000020000000200000002000000020000000200000002000000020000000200000002000000020000000
00200020002000200020002000200020002000200020002000200020002000200020002000200020002000200020002000200020002000200020002000200020
02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202
20002000200020002000200020002000200020002000200020002000200020002000200020002000200020002000200020002000200020002000200020002000
02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202
20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202
20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
02220222022202220222022202220222022202220222022202220222022202220222022202220222022202220222022202220222022202220222022202220222
20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020
22022202220222022202220222022202220222022202220222022202220222022202220222022202220222022202220222022202220222022202220222022202
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
22222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007700000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000770000
00000000044444444444488000000000044444444444800000444444848000000000000044444444444800000004444444444444800000000000000000077000
00000000444444444444848000000000444444444444800004444448488000000000000444444444444800000044444444444444800000000000000000778800
00000004444444444448488000000004444444444444800044444484880000000000004444844444444800000444448444444444800000000000000007788000
00000044444444444484880000000044444444444444800444444848800000000000044448488844444800004444484888444444800000000000000000880000
00000444444844444848800000000444444448444444800444448488000000000000444444880044444800044444448800444448800000000000000000000000
00004444448488888888000000004444444484844444800444444880000000000004444448800044444800044444488000444484800000000000000000000000
00044444484880000000000000044444444848844444800444448800000000000004444448000444444800044444480004444848800000000000000000000000
00044444848800444444480000444444448488044444800444448000000000000004444448004444444800044444480044448488000000000000000000000000
00044444488004444444480004444444484880044444800444448000000000000004444448044444444800044444480444484880000000000000000000000000
00044444880044444444480044444444848800044444800444448000000000000004444448444444444800044444484444448800000000000000000000000000
00044444800444444444480044444448488000044444800444448000000000000004444444448444444800044444444444444800000000000000000000000000
00044444804444444444480044444484880000444444800444448000000000000004444444484844444800044444448444444480000000000000000000000000
00044444444444844444480044444848800004444444800444448000000000000004444444848844444800044444484844444448000000000000000000000000
00044444444448484444480044444488000044444444800444448000000000000004444448488044444800044444848884444444800000000000000000000000
00044444444484884444480044444880000444444448800444448000000000000004444484880044444800044444488008444444800000000000000000000000
00044444444848804444480044444800004444444484800444448000000000000004444448800044444800044444880000844444800000000000000000000000
00044444448488004444480044444800044444444848800444448000000000000004444488000044444800044444800000044444800000000000000000000000
00044444484880044444480044444800444444448488000444448000000000000004444480000044444800044444800000044444800000000000000000000000
00044444848800444444880044444804444444484880000444448000000000000004444480000044444800044444800000044444800000000000000000000000
00088888888004444448480044444844444444848800000444448000000000000004444880000044448800044448800000044448800000000000000000000000
00000000000044444484880044444444444448488000000444448000000000000004448480000044484800044484800000044484800000000000000000000000
00000444444444444848800044444444444484880000000444444444444444848004484880000044848800044848800000044848800000000000000000000000
00004444444444448488000044444444444848800000000444444444444448488004848800000048488000048488000000048488000000000000000000000000
00044444444444484880000044444444448488000000000444444444444484880008488000000084880000084880000000084880000000000000000000000000
00444444444444848800000044444444484880000000000444444444444848800004880000000048800000048800000000048800000000000000000000000000
00888888888888888000000088888888888800000000000888888888888888000008800000000088000000088000000000088000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000044444444444488000000000000044444448480000044444444448480000004444444444848000044444484800000000000000000000000000000
00000000000444444444444848000000000000444444484880000444444444484880000044444444448488000444444848800000000000000000000000000000
00000000004444444444448488000000000004444444848800004444444444848800000444444444484880004444448488000000000000000000000000000000
00000000044444444444484880000004444444444448488000044444444448488000004444444444848800044444484880000000000000000000000000000000
00000000444444844444848800000044444444444484880000444448484484880000044444848448488000044444848800000000000000000000000000000000
00000004444448488888888000000444444444444848800004444484888888800000444448488888880000044444488000000000000000000000000000000000
00000044444484880000000000004444448444448488000004444448800000000000444444880000000000044444880000000000000000000000000000000000
00000044444848800444444480044444484844444880000004444488000000000000444448800000000000044444800000000000000000000000000000000000
00000044444488004444444480044444848844444800000004444480000000000000444448000000000000044444800000000000000000000000000000000000
00000044444880044444444480044448488044444800000004444480000000000000444448000000000000044444800000000000000000000000000000000000
00000044444800444444444480088888880044444800000004444444444444848000444444444444484800044444800000000000000000000000000000000000
00000044444804444444444480000000000044444800000004444444444448488000444444444444848800044444800000000000000000000000000000000000
00000044444444444844444480000000000044444800000004444444444484880000444444444448488000044444800000000000000000000000000000000000
00000044444444448484444480000000000044444800000004444444844848800000444444484484880000044444800000000000000000000000000000000000
00000044444444484884444480000000000044444800000004444448488888000000444444848888800000044444800000000000000000000000000000000000
00000044444444848804444480000000000044444800000004444484880000000000444448488000000000044444800000000000000000000000000000000000
00000044444448488004444480000000000044444800000004444448800000000000444444880000000000044444800000000000000000000000000000000000
00000044444484880044444480000000000044444800000004444488000000000000444448800000000000044444800000000000000000000000000000000000
00000044444848800444444880000000000044444800000004444480000000000000444448000000000000044444800000000000000000000000000000000000
00000088888888004444448480000000000044448800000004444480000000000000444448000000000000044444800000000000000000000000000000000000
00000000000000044444484880000000000044484800000004444444444444484800444444444444448480044444800000000000000000000000000000000000
00000000444444444444848800000000000044848800000004444444444444848800444444444444484880044444444444444484800000000000000000000000
00000004444444444448488000000000000048488000000004444444444448488000444444444444848800044444444444444848800000000000000000000000
00000044444444444484880000000000000084880000000004444444444484880000444444444448488000044444444444448488000000000000000000000000
00000444444444444848800000000000000048800000000004444444444848800000444444444484880000044444444444484880000000000000000000000000
00000888888888888888000000000000000088000000000008888888888888000000888888888888800000088888888888888800000000000000000000000000
__label__
0000000000000000000000000000000000000000000000000000000000000j000000000000000000000000000000000000000000000000000000000000000000
0000000000000j000000000000000000000000000000000000000000000000000000000000000000000000j00000000000000000000000000000000000000000
000000000000jjj00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0j00000000000j000000000000000000000000000000000000000000j000000000000000000000000000000000000000000000000j0000000000000000000000
0000000000000000000000000000000000000000000000000000000jjj00000j0000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000j00000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000j0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000j000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000j0000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000j0000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000jjj000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000j0000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000j000000000000
00000000000000000000000000000000000000000000j000000000000000000000000000000000000000000000000000000000000000000000jjj00000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000j000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000j000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000jjj00000000000000000000000000000000000000000000000000000000000000000000000000000000j00000000000000000000000000000000
0000000000000j00000tttttttttttt880000000000ttttttttttt800000tttttt8t80000000000000ttttttttttt80000000ttttttttttttt80000000000000
000000000000000000tttttttttttt8t8000000000tttttttttttt80000tttttt8t88000000000000tttttttttttt8000000tttttttttttttt80000000000000
00000000000000000tttttttttttt8t8800000000ttttttttttttt8000tttttt8t88000000000000tttt8tttttttt800000ttttt8ttttttttt80000000000000
0000000000000000tttttttttttt8t8800000000tttttttttttttt800tttttt8t88000000000000tttt8t888ttttt80000ttttt8t888tttttt80000000000000
000000000000000tttttt8ttttt8t8800000000tttttttt8tttttt800ttttt8t88000000000000tttttt8800ttttt8000ttttttt8800ttttt880000000000000
00000000000000tttttt8t888888880000j000tttttttt8t8ttttt800tttttt88000000000000tttttt88000ttttt8000tttttt88000tttt8t800000j0000000
0000000000000tttttt8t8800000000000000tttttttt8t88ttttt800ttttt880000000000000tttttt8000tttttt8000tttttt8000tttt8t880000jjj000000
0000000000000ttttt8t8800ttttttt80000tttttttt8t880ttttt800ttttt800000000000000tttttt800ttttttt8000tttttt800tttt8t88000000j0000000
0000000000000tttttt8800tttttttt800jtttttttt8t8800ttttt800ttttt800000000000000tttttt80tttttttt8000tttttt80tttt8t88000000000000000
0000000000000ttttt8800ttttttttt800tttttttt8t8800jttttt800ttttt800000000000000tttttt8ttttttttt8000tttttt8tttttt880000000000000000
0000000000000ttttt800tttttttttt800ttttttt8t880000ttttt800ttttt800000000000000ttttttttt8tttttt8000tttttttttttttt80000000000000000
0000000000000ttttt80ttttttttttt800tttttt8t880000tttttt800ttttt800000000000000tttttttt8t8ttttt8000ttttttt8ttttttt800j000000000000
0000000000000ttttttttttt8tttttt800ttttt8t880000ttttttt800ttttt800000000000000ttttttt8t88ttttt8000tttttt8t8ttttttt800000000000000
0000000000000tttttttttt8t8ttttt800tttttt880000tttttttt800ttttt800000000000000tttttt8t880ttttt8000ttttt8t888ttttttt80000000000000
0000000000000ttttttttt8t88ttttt800ttttt880000tttttttt8800ttttt800000000000000ttttt8t8800ttttt8000tttttt88008tttttt80000000000000
0000000000000tttttttt8t880ttttt800ttttt80000tttttttt8t800ttttt800000000000000tttttt88000ttttt8000ttttt88jj008ttttt80000000000000
0000000000000ttttttt8t8800ttttt800ttttt8000tttttttt8t8800ttttt800000000000000ttttt880000ttttt8000ttttt80j0000ttttt80000j00000000
0000000000000tttttt8t8800tttttt800ttttt800tttttttt8t88000ttttt800000000000000ttttt800000ttttt8000ttttt8000000ttttt80000000000000
0000000000000ttttt8t8800tttttt88jjttttt80tttttttt8t880000ttttt800000000000000ttttt800000ttttt8000ttttt8000000ttttt80000000000000
00000000000008888888800tttttt8t8jjttttt8tttttttt8t8800000ttttt800000000000000tttt8800000tttt88000tttt88000000tttt880000000000000
0000000000000000000000tttttt8t880jttttttttttttt8t88000000ttttt800000000000000ttt8t800000ttt8t8000ttt8t8000000ttt8t80000000000000
000000000000000tttttttttttt8t88000tttttttttttt8t880000000ttttttttttttttt8t800tt8t8800000tt8t88j00tt8t88000000tt8t880000000000000
00000000000000tttttttttttt8t880000ttttttttttt8t8800000000tttttttttttttt8t8800t8t88000000t8t88jjj0t8t880000000t8t8800000000000000
0000000000000tttttttttttt8t8800000tttttttttt8t88000000000ttttttttttttt8t880008t8800000008t8800j008t88000000008t88000000000000000
000000000000tttttttttttt8t88000000ttttttttt8t880000000000tttttttttttt8t880000t8800000000t88000000t88000000000t880000000000000000
0000000000008888888888888880000000888888888888000000000008888888888888880000088000j00000880000000880000000j008800000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000jjj000000000000000000000jjj00000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000j00000000000000000000000j00j000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000j0000000000000000000j00000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000j00000000000000000000000000000000000jjj0000000000000000000000000000000000
000000000000000000000jtttttttttttt880000000000000ttttttt8t800000tttttttttt8t8000000tttttttttt8t80000tttttt8t80000000000000000000
000000000000000000000tttttttttttt8t8000000000000ttttttt8t880000tttttttttt8t8800000tttttttttt8t88000tttttt8t880000000000000000000
00000000000000000000tttttttttttt8t8800000000000ttttttt8t880000tttttttttt8t8800000tttttttttt8t88000tttttt8t8800000000000000000000
0000000000000000000tttttttttttt8t88000000tttttttttttt8t880000tttttttttt8t8800000tttttttttt8t88000tttttt8t88000000000000000000000
000000000000000000tttttt8ttttt8t88000000tttttttttttt8t880000ttttt8t8tt8t8800000ttttt8t8tt8t880000ttttt8t880000000000000000000000
00000000000000000tttttt8t88888888000000tttttttttttt8t880000ttttt8t888888800000ttttt8t888888800000tttttt8800000000000000000000000
0000000000000000tttttt8t88000000000000tttttt8ttttt8t8800000tttttt8800000000000tttttt8800000000000ttttt88000000000000000000000000
0000000000000000ttttt8t8800ttttttt800tttttt8t8ttttt88000000ttttt88000000000000ttttt88000000000000ttttt80000000000000000000000000
0000000000000000tttttt8800tttttttt800ttttt8t88ttttt80000000ttttt80000000000000ttttt80000000000000ttttt80000000000000000000000000
0000000000000000ttttt8800ttttttttt800tttt8t880ttttt80000000ttttt80000000000000ttttt80000000000000ttttt80000000000000000000000000
0000000000000000ttttt800tttttttttt800888888800ttttt80000000ttttttttttttt8t800jttttttttttttt8t8000ttttt80000000000000000000000000
0000000000000000ttttt80ttttttttttt800000000000ttttt80000000tttttttttttt8t8800jtttttttttttt8t88000ttttt80000000000000000000000000
0000000000000000ttttttttttt8tttttt800000000000ttttt80000000ttttttttttt8t88000jttttttttttt8t880000ttttt80000000000000000000000000
0000000000000000tttttttttt8t8ttttt800000000000ttttt80000000ttttttt8tt8t8800000ttttttt8tt8t8800000ttttt80000000000000000000000000
0000000000000000ttttttttt8t88ttttt800000000000ttttt80000000tttttt8t88888000000tttttt8t88888000000ttttt80000000000000000000000000
0000000000000000tttttttt8t880ttttt800000000000ttttt80000000ttttt8t880000000000ttttt8t880000000000ttttt80000000000000000000000000
0000000000000000ttttttt8t8800ttttt800000000000ttttt80000000tttttt8800000000000tttttt8800000000000ttttt80000000000000000000000000
00j0000000000000tttttt8t8800tttttt800000000000ttttt80000000ttttt88000000000000ttttt88000000000000ttttt80000000000000000000000000
0000000000000000ttttt8t8800tttttt8800000000000ttttt80000jjjttttt80000000000000ttttt80000000000000ttttt80000000000000000000000000
00000000000000008888888800tttttt8t800000000000tttt88000jjjjttttt800000000000j0ttttt80000000000000ttttt80000000000000000000000000
0000000000000000000000000tttttt8t8800000000000ttt8t8000jjjjtttttttttttttt8t800tttttttttttttt8t800ttttt80000000000000000000000000
00000j000000000000tttttttttttt8t88000000000000tt8t88000jjjjttttttttttttt8t8800ttttttttttttt8t8800ttttttttttttttt8t80000000000000
0000jjj0000000000tttttttttttt8t880000000000000t8t8800000jjjtttttttttttt8t88000tttttttttttt8t88000tttttttttttttt8t880000000000000
00000j0000000000tttttttttttt8t88000000000000008t88000000000ttttttttttt8t880000ttttttttttt8t880000ttttttttttttt8t8800000000000000
000000000000000tttttttttttt8t88000000000000000t880000000000tttttttttt8t8800000tttttttttt8t8800000tttttttttttt8t88000000000000000
00000000000000088888888888888800000000000000008800000000000888888888888800000088888888888880000008888888888888880000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000j000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000j0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00jjj00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000j000000000000000000000
jjjj00000000000000000000000000000000000000000000000000000000000000000000000000j0000000000000000000000000000000000000000000000000
jjjj0000000000000000000000000000000000000000000000000000000000000000000000000jjj0000000000000000000000000000j00000000000j0000000
jjjjj0000000000000000000000000000000000000000000000000000000000000000000000000j0000000000000000000000000000jjj000000000jjj000000
jjjjj0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000j00000000000j0000000
jjjjj00000000000000000000000j0000000000000000000000000000000000000000000000000000j0000000000000000000000000000000000000000000000
jjjj0000000000000000000000000000000000000000000000000000000000000000000000000000jjj00000000000000000000000000000000000j000000000
jjjj00000000000000000000000000000000000000000000000000000000000000000000000000000j0000000000000000000000000000000000000000000000
00jjj000000000000j00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000j00000000000000000000000000000000000000000000000000000000000000000000000j0000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000j00000000000000000000000000000000000jjj000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000j0000000000000000000000000000000000000000000000000000
000000000000000000000000000000j000000000000000000000000000000000000000j0000000000000000000j0000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000jjj0000j000000000000jjj00000000000j000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000j0000000000000000000j000000000000j000000000000000000000000
000000000000000000000000000000000000000000j00000000000000000000000000000000000000000000000000000000000jjj00000000000000000000000
000000000000jjj000j0000000000000000000000jjj00000000000000000000000000000000000000000000000000000000000j000000000000000000000000
00000000000jjjjj00000000000000000000000000j0000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000jjjjj000000000000000000000000000000000000000000000000000000000000000000000j000000000000000000000000000000000000000000
000j0000000jjjjj00000000000000000000000000000000000j00000000000000000000000000000000jjj00000000000000000000000000000000000000000
00jjj0000000jjj0000000000000000000000000000000000000000000000000000000000000000000000j000000000000000000000000000000000000000000
000j0000000000000000000000j00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000j0000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000j00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000j00000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000j000000000000000000000000000j00000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000jjj0000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000j00000000000000j00000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000j000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000j000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000j000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000j0000000000000000000000000000000000j000000000000000000j00000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000j000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000j00000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__sfx__
010100003c6003a6003b600386003660036600336003a600316002f6002d6002a60027600246001e6001b60017600146000f6000d6000a6000860006600056000260001600006000c6000a600076000660004600
01080020130330f605286332440013053006031760500603286330460317605006031303300603286330060317605006032863304603130330060313053006032863300603286330460313033006032863300000
011000200032504325083250a3250032504325083250c3250032504325083250a3250c325103250c325103250032504325083250a3250032504325083250c3250032504325083250a32500325043250232504325
011000000c4250c42510425164250c4250c42510425164250c4250c42510425114250c4250c42510425114250c4250c42510425164250c4250c42510425164250c4250c42510425114250c4250c4251042511425
011000000032500325043250a32504325043250032500325043250a3250432504325083250432504325083250032500325043250a32504325043250032500325043250a325043250432500325083250a3250a325
011000002e0122e0122e012240122401224012280122801229012290122901228012280122801222012220122401224012240122201222012220121d0121d0122201222012220122801228012280122901229012
011000200c5351053514535165350c5351053514535165350c535105351453516535145351053514535135350c5351053514535165350c5351053514535165350c53510535145351653514535105351453513535
011000000041000410044100a41008410084100041000410044100a41008410084100a4100441004410054100041000410044100a41008410084100041000410044100a410084100841000410044100441005410
01080020130331f4032470524403185003f4031303300503286430460328705006032440300603225132020013033297001303304603225130060328705006032864324705130330460322513006032251300003
01080020130331f4031300324403225133f4031303300503286330460328705006032251300603286330060333503297002860304603130330060322513006032863324705130030460322513006032863300003
011000001831518315183151b3151b3151b31518315183152431524315243152031520315203151d3151d3151f3151f3151f3152031520315203151c3151c3151d3151d3151d3151b3151b3151b3151a3151a315
011000002421524214242152421524215242152421524215242152421424215242152421524215242142421524215242142421524215242152421524214242152421524215242152421524215242152421524215
01100020130231f40337113286333f40337113286232860304603130233711328623006033712328623130233c62513023244003c62500603130233c625286033c62513023130233c6253c625286033c62500000
01080020130331f6052460500605206350f6052460500605130331f6051303300605206350f6052460500605130531f6051303300605206350f6052460500605221051f6051303300605206350f6052210500605
01080020130331f6051303300605206350f6051303300605130331f6051303300605206350f6051303300605130331f6051303300605206350f6051303300605130331f6052063500605206350f6052063500605
0108002013033006051303300605206351f605130330060513033006051303300605206351f605130330060513033006051303300605206351f6051303300605130330f6051303300605206350f6052063500000
01080020130331f6051300000605206350f60513000006050a0001f6051303300605206350f60524605006050a0001f6051303300605206350f6052460500605130331f6050a00000605206350f6052210500605
0110002010537105370c537005370a53708537085370853711537115370c5370c5370853710537105371053711537115370c5370c5370a53708537085370853714537145370c5370c537085370f5370f5370f537
011000202220522205202051f2051f20518205182051820520205202051f2051b2051b20516205162051620518205182051c2051d2051d2051d2051b2051a2051820518205182051b2051d2051d2051b20516205
0002000014652146521465214652181521817219172191721917219172191721817218172171721617215172111720e1720c1720c1420c642104020f5020f5020f5020e5020d5020c5020a502144020950208502
0101000037335373350d1050d1050d1052a4052a4052a405006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605
00020000250312103128031240312a031270312b031270312a031250312703121031230311c0311e0311703119031130310e03109031050310103100031000310000104001030010200100001000010600105001
00060000385303b5303f5303f5003f5003f5003f5003a5003950039500395003950039500395003950039500395003950039500395003a5003b5003b5003c5003d5003e5003f5000050000500005000050000500
010300003f5373e5373f5373e5373e5373d5373f5373c5373d5373e5373f5373f53739507395073950739507395073950739507395073a5073b5073b5073c5073d5073e5073f5070050700507005070050700507
000200003c6253c6253c6253c6253c7203c7203c7203c7203c7203c7203c7203c7203c7103c7103c7103c7103c7103c7103c7103c7103c7103c7103c7103c7103c7103c7103c7103c7003c7003c7003c7003c700
0003000020634256341d63424634171321613215132141321313212132111320f1320d1320c1320a1340d1020c1020a1040020400204002040020400204002040020400204002040020400204002040020400204
0001000001532025320553207532095320c5321153212532145321653217532195321c5321f5322053220532205322053220532205321e5321d5321b5321b5321a53219532175321253212532105320e5320b532
000200000053101531015310153101531065310a5310f531185311f53127531345313f531105011250116501185011c50121501275012f5013d5012c5012e501335013450137501385013b5013b5013f5013f501
00030000004200142001420024200442005420064200742008420084200a4200b4200c4200d4200e42010420124201342015420194201e42021420264202a420314201d4001e4001f40020400224002440024400
00020000323252b325313252c325313202c320323202f320333203032035220352203521035210352103521035210352103521035210352103521035210352103521035200352003530034300363003c3003c300
012000200070100731007310073100731007310071100701047010473104731047310473104731047110470103001037310373103731037310373103711030010100101731017310173101731017310171101001
012000200555505535055350553505535055550555505555055550555505555055550555505555055550555505555055550555505555055550555505555055550555505555055550555505555055550555505555
011000000d0150d01511015110150d0150d015110151101517015170150d0150d015170151701514015140150d0150d0151101511015140151401517015170150d0150d015110151101514015140151701517015
011000000d5151151517515145150d51511515175151451517515145150d5151151517515175150d5150d5150d5151151517515145150d51511515175151451517515145150d5151151517515175150d5150d515
011000001c5151c5151c5151951519515195151c5151c5151c5151e5151e5151e5152051520515205151e5151e5151e5151b5151b5151b5151c5151c5151c5151e5151e5151e5152051520515205151951519515
011000001711517115171151711517115171151711517115171151711517115171151711517115171151711519115191151911519115191151911519115191151911519115191151911519115191151911519115
011000001211512115121151211512115121151211512115121151211512115121151211512115121151211514115141151411514115141151411514115141151411514115141151411514115141151411514115
011000002051520515205151d5151d5151d5151e5151e5151e5152051520515205152351523515235151e5151e5151e5152051520515205151c5151c5151c5151e5151e5151e5151b5151b5151b5151e5151e515
011000000d1150d1150d1150d1150d1150d1150d1150d1150d1150d1150d1150d1150d1150d1150d1150d1150d1150d1150d1150d1150d1150d1150d1150d1150d1150d1150d1150d1150d1150d1150d1150d115
011000001c5151c5151c5151951519515195151c5151c5151c5151e5151e5151e5152051520515205151e5151e5151e5151b5151b5151b5151c5151c5151c5151e5151e5151e5152051520515205151951519515
011000001111511115111151111511115111151111511115111151111511115111151111511115111151711517115171151711517115171151711517115171151711517115171151711517115171151711517115
011000002051520515205151d5151d5151d5151e5151e5151e5152051520515205152351523515235151e5151e5151e5152051520515205151c5151c5151c5151e5151e5151e5151b5151b5151b5151e5151e515
011000001911519115191151911519115191151911519115191151911519115191151911519115191151911519115191151911519115191151911519115191151911519115191151911519115191151911519115
0110000025515255152551528515285152851527515275152751528515285152851527515275152751527515255151b0001950019500195001950019500195001950019500195001950019500195001950019500
011000001101511015110151001510015100150f0150f0150f0151001510015100150f0150f0150f0150f0150d0150d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d000
011000000d5251152517525145250d52511525175251452517525145250d5251152514525115250d5250d5250d5251150517505145050d50511505175051450517505145050d5051150517505175050d5050d505
011000001911519115191151911519115191151911519115191150d1150d1150d1150d1150d1150d1150d1150d115191001910019100191001910019100191001910019100191001910019100191001910019100
011000000c5100c5100c5100c5100c5100c5100c5100c5100e5100e5100e5100e5101351013510135101351011510115101151011510145101451014510145101651016510165101651014510145101451014510
01100000137101371013710137100f7100f7100f7100f710117101171011710117100e7100e7100e7100e7100c7100c7100c7100c7100f7100f7100f7100f7100e7100e7100e7100e71011710117101171011710
0110000013710137100f7100f7100e7100e71013710137100e7100e7100c7100c71013710137100e7100e7100c7100c710137101371011710117100c7100c71013710137100e7100e7100c7100c7101671016710
011000001861518605186151861518615186051861518605186151860518605186051861518605186051861518615186051861518605186151860518605186151861518605186051860518615186051861518615
011000000f5100f5100f5100f510135101351013510135100e5100e5100e5100e510165101651016510165100c5100c5100c5100c510115101151011510115100e5100e5100e5100e51011510115101151011510
011000000c5100c5100c5100c5100e5100e5100e5100e510115101151011510115100f5100f5100f5100f5100f5100f5100f5100f5100c5100c5100c5100c5101651016510165101651014510145101451014510
011000000072500725047250a72504725047250072500725047250a7250472504725087250472504725087250072500725047250a72504725047250072500725047250a725047250472500725087250a7250a725
0110000000515005150051503515035150351500515005150c5150c5150c515085150851508515055150551507515075150751508515085150851504515045150551505515055150351503515035150251502515
011000200c7151071514715167150c7151071514715167150c715107151471516715147151071514715137150c7151071514715167150c7151071514715167150c71510715147151671514715107151471513715
011000001171511715117150c7150c7150c71510715107151171511715117151071510715107150a7150a7150c7150c7150c7150a7150a7150a71505715057150a7150a7150a7151071510715107151171511715
011000200071504715087150a7150071504715087150c7150071504715087150a7150c715107150c715107150071504715087150a7150071504715087150c7150071504715087150a71500715047150271504715
0001000002610136100661017610096101a6100d6101f610136102161018610236101a610246101b610246101b610236101c610236101c610246101d610246101d610246101d610246101d610236101d61023610
011000001671516715167150c7150c7150c71510715107151171511715117151071510715107150a7150a7150c7150c7150c7150a7150a7150a71505715057150a7150a7150a7151371513715137151171511715
000400003e6103e6003d600243001e3001d3000130000300003000030010300003001130011300003001230012300003001330000300003000030000300003000030000300003000030000300003000030000300
00060000295302c5302f5301c5003f5003f5003f5003a5003950039500395003950039500395003950039500395003950039500395003a5003b5003b5003c5003d5003e5003f5000050000500005000050000500
00020000250312103128031240312a031270312d0312a0312f0312b031310312a0312d03123031270311b03117031130310e03109031050310103100031000310000104001030010200100001000010600105001
__music__
01 08044445
00 08040645
00 08045145
00 08020645
00 09030545
00 01030b45
00 08040b45
00 08040645
00 08040b45
00 08020645
00 090a0b45
00 0a054945
00 08074744
00 09074744
00 08071144
00 09071144
00 08114444
00 09114144
00 49110b44
00 08070b44
00 09070b44
00 01070b44
00 04050b45
00 104b0445
00 0d4b0445
00 0f0b0445
00 0e050a45
00 0d0a0744
00 0f0a0744
00 0e0b0744
02 04050b45
00 81828384
00 21606263
00 21206263
00 21202622
00 21202524
00 21202528
00 2120222a
00 2b2c2d2e
00 6b6c6d6e
03 5e5f4445
01 61606263
00 21206263
01 21202622
00 21202524
00 21202723
00 21202928
01 2120292a
01 35767172
00 35377172
00 35767172
00 39377172
00 35767172
00 35377172
00 35367172
02 3b367072
00 35767172
00 35377172
00 35767172
00 39377172
00 35387172
00 35367172
00 35377172
00 35367172

