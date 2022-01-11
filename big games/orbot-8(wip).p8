pico-8 cartridge // http://www.pico-8.com
version 32
__lua__
--orbot-8
--by fuzzydunlop

--=======
--GLOBALS
--=======

--player
lives=5
score=0
py=-38
pdy=0
cur_checkpoint={t=10,y=7}
cur_checkpoint_score=0

--anim
player_anim={}
j_anim={fin=true}

--gravity
grv=-3

--time
tim=0
real_tim=0

--path line
prjj=0
prjg=0
v_j_dist=0

--text animation
txt_cor=nil

--walls/collisions
walls={}

sparks={}


--should refactor more functions to follow below "params" pattern
params={
  gen={
    chunks_per_chck=3,
    total_chunks=50,
    sticky_fact=1.5,
    diff_breadth=3
  },
}

static={
	px=14,
	screen_time=240,
  col_d=6.6,
  star_speed=5,
  ground_mult=5,
  frame_score=.05,
  grv_change_rate=2,
	hold_amt=2,
	turn_rate=0.25,
	time_rate=1,
	time_rate_accel=0,--0.00005
	mxgrv=3,
	gf=50,--100
	ymin=-38,       
	ymax=38,
	jmph=1.35,
	scenery_spr={25,41,57,30,29,31},
	scenery_interval=1.5,
	rewind_len=90,
  rewind_penalty=10,
  sparks_x_vel=1,
  sparks_y_vel=1,
  sparks_x_drag=.01,
  sparks_amt=4,
  jump_sparks=10
}

constant={
  seed=nil,
  gen_chunks={},
  conn_walls={},
  checkpoints={},
  cchart={}
}

loop_enum={
  title='title',
  spawning='spawning',
  game='game',
  died='died',
  respawn_menu='respawn_menu',
  rewinding='rewinding',
  game_over='game_over'
}

current_loop=nil

function _init()

  -- printh('init================================')

  local p=params.gen

  --create generation seeds
  constant.seed=rnd(100)
--  srand(stat(90)+stat(91)+stat(92))

  local chunk_list={}
  local last_chunk_t=0
  local last_gen_exts=nil

  local nxt_chunk_t=1
  local lst_ext_conns=nil
  local chck_num=0

  function add_chunk(c,r)
    -- printh('added chunk t='..c.t..' rev:'..tostr(r))
    
    --add checkpoint
    chck_num+=1
    if chck_num%p.chunks_per_chck==0 then
      add(constant.checkpoints,{t=nxt_chunk_t,y=(r and c.chck or 7-c.chck)})
    end

    --add chunk connectors
    local bord=c.borders
    local nxt_ent_conns,nxt_ext_conns={},{}
    nxt_ent_conns.t=r and reverse_set(bord.ent.b) or bord.ent.t
    nxt_ent_conns.b=r and reverse_set(bord.ent.t) or bord.ent.b
    nxt_ext_conns.t=r and reverse_set(bord.ext.b) or bord.ext.t
    nxt_ext_conns.b=r and reverse_set(bord.ext.t) or bord.ext.b

    if lst_ext_conns then

      local new_ext_conns={t={},b={}}
      local new_ent_conns={t={},b={}}

      local inn_ext_t=lst_ext_conns.t[#lst_ext_conns.t] 
      local inn_ext_b=lst_ext_conns.b[1]
      local inn_ent_t=nxt_ent_conns.t[#nxt_ent_conns.t]
      local inn_ent_b=nxt_ent_conns.b[1]

      local top_side=inn_ext_t>inn_ent_t and new_ext_conns.t or new_ent_conns.t
      
      for n=inn_ent_t,inn_ext_t,sgn(inn_ext_t-inn_ent_t) do
        if(has(nxt_ent_conns.t,n) and has(lst_ext_conns.t,n))break
        add(top_side,n)
      end  

      local bot_side=inn_ext_b<inn_ent_b and new_ext_conns.b or new_ent_conns.b
    
      for n=inn_ent_b,inn_ext_b,sgn(inn_ext_b-inn_ent_b) do
        if(has(nxt_ent_conns.b,n) and has(lst_ext_conns.b,n))break
        add(bot_side,n)
      end

      constant.conn_walls[nxt_chunk_t-1]=new_ext_conns
      constant.conn_walls[nxt_chunk_t]=new_ent_conns
    end

    --add to gen_chunks, update vars
    lst_ext_conns=nxt_ext_conns
    last_chunk_t=c.t
    constant.gen_chunks[nxt_chunk_t]={t=c.t,r=r}
    nxt_chunk_t+=c.len
    last_gen_exts=r and reverse_set(c.ext) or c.ext
  end

  function get_border_walls(x,y)
    local top_bord,bot_bord={},{}
    for yi=0,7 do
      local s=mget(x,y+yi)
      if(s==1)add(bot_bord,yi)
      if(s==2)add(top_bord,yi)
    end
    if(#bot_bord==0)bot_bord={7}
    if(#top_bord==0)top_bord={0}
    return{t=top_bord,b=bot_bord}
  end

  function rnd_chunk(exc,row)
    local list=chunk_list[row]
    local c=list[rnd(#list)\1+1]
    while(c.t==exc) do
      c=list[rnd(#list)\1+1]
    end
    return c
  end

  --populate chunk_list
  local chunk={borders={}}
  
  for i=0,1024 do

    local x,row=i%128
    local row=i\128
    local y=row*8

    for yi=0,7 do

      local y2=y+yi
      local s=mget(x,y2)

      if(s==16)chunk.chck=yi

      if s==23 then
        add2(chunk,'ent',yi)
        chunk.t=i+1
        if not chunk.borders.ent then
          chunk.borders.ent=get_border_walls(x+1,y)
        end
      end

      if s==24 then
        add2(chunk,'ext',yi)
        if not chunk.borders.ext then
          chunk.borders.ext=get_border_walls(x-1,y)
        end
      end
    end 

    if chunk.ext then
      chunk.len=i-chunk.t
      add2(chunk_list,row+1,chunk)
      chunk={borders={}}
    end
  end

  --calculate chunk difficulty spread
  local diff_int=(p.total_chunks-1)/7
  local range=p.diff_breadth*diff_int
  local intervals={}
  for i=1,8 do
    intervals[i]=(i-1)*diff_int
  end

  --populate gen_chunks,checkpoints,wall_conn
  add_chunk(rnd_chunk(nil,1),rnd(2)<2)

  for ci=0,p.total_chunks-1 do

    local weights={}
    for j=1,#intervals do
      local prox=abs(intervals[j]-ci)*p.sticky_fact
      weights[j]=max(range-prox,0)
    end
    local row=nil
    local tot=0
    for w in all(weights) do
      tot+=w
    end
    local r=rnd(tot)
    for i=1,#weights do
      if r<weights[i] then
        row=i
        break
      end
      r-=weights[i]
    end

    local searching=true
    while(searching) do
      local c=rnd_chunk(last_chunk_t,row)
      local rev=rnd(2)<1
      for e in all(last_gen_exts) do
        if(rev)e=7-e
        if has(c.ent,e) then
          add_chunk(c,rev)
          searching=false
          break
        end
      end 
    end
  end

  --populate bezier curve chart
  for x=0,1360,1 do
    local t=(x)/1360
    local b=bez_point(-8,104,127,127,.35,.06,.3,.1,t)
    constant.cchart[x]=b.y
  end

  --set current loop
  title_loop_init()
end


function _update60()
  local cl,le=current_loop,loop_enum
  if(cl==le.title)title_update()
  if(cl==le.game)game_update()
  if(cl==le.died)died_update()
  if(cl==le.respawn_menu)respawn_menu_update()
  if(cl==le.rewinding)rewinding_update()
  if(cl==le.spawning)spawning_update()
  if(cl==le.game_over)game_over_update()
end


function _draw()
  pal(9,142,1)
  pal(13,140,1)
  local cl,le=current_loop,loop_enum
  if(cl==le.title)title_draw()
  if(cl==le.game)game_draw()
  if(cl==le.died)died_draw()
  if(cl==le.respawn_menu)respawn_menu_draw()
  if(cl==le.rewinding)rewinding_draw()
  if(cl==le.spawning)spawning_draw()
  if(cl==le.game_over)game_over_draw()
  -- draw_stats()
end

function draw_stats()
  print('cpu:',102,0,7)
  print(((tonum(stat(1))*100)\1)..'%',117,0,7)
  print('mem',105,12,7)
  print((stat(0)/2048)*100,105,18,7)
end



--==========
--TITLE LOOP
--==========

title_t=0 
fade_t=0
title_clr={0,5,6,15,15,15,15,15,15,15,15,15,15,15,15,6,5}


function title_loop_init()
  score=0
  py=-38
  pdy=0
  cur_checkpoint={t=10,y=7}
  cur_checkpoint_score=0
  tim=0
  real_tim=0
  lives=10
  grv=-3
  walls={}
  sparks={}
  collisions={}
  prjj=0
  prjg=grv/static.gf

  title_t=0
  fade_t=0
  -- music(32)
  current_loop=loop_enum.title
end


function title_update()
  title_t+=1
  if(fade_t==0 and (btnp(4) or btnp(5)))fade_t+=60 sfx(17)
  if fade_t>0 then 
    fade_t-=1
    if(fade_t==0)game_loop_init()
  end
end


function title_draw()
  cls()
  if fade_t>0 then
    if(fade_t==59)cls(6)
    if(fade_t>55)pal(8,5)pal(12,5)pal(15,5)
    if(fade_t>57)pal(8,6)pal(12,6)pal(15,6)
  end
  sspr(0,21,72,38,27,40,72,38)
  local c_t=((title_t/6)%#title_clr)\1+1
  print('❎ or 🅾️ to start',30,80,title_clr[c_t])  
  if fade_t>0 and fade_t<54 then
    pal()
    cls()
  end
end

--=========
--GAME LOOP
--=========

check_txt=0
btn_hold=0

function game_loop_init()
  start_anim(player_anim,player_ground_anim)
 -- music(0)
  -- grv=-static.mxgrv
  current_loop=loop_enum.game
end


function game_update()

  get_walls()

  --get checkpoints
  if check_txt>0 then
    check_txt-=1
  else
    txt_cor=nil
  end

  local chck_tim=tim\10-static.screen_time\10+2
  for c in all(constant.checkpoints) do
    if(tim\10==cur_checkpoint.t\1)break
    if c.t==chck_tim then
      cur_checkpoint={t=tim\10+.3,y=c.y}
      cur_checkpoint_score=score
      sfx(9)
      check_txt+=60
      break
    end
  end

  --get collisions
  for w in all(walls) do
    if mid(5,w.x,16)==w.x then
      local cx,cy=w.x+3.5,w.y+3.5
      local d=(cx-static.px)^2+(cy-(64-py))^2
      if d<=static.col_d^2 then
      	died_loop_init()
      end
    end
  end
  collisions={} 

  --get input / update gravity / start jump / add sparks
  if(btn(1) or btn(0)) then
    if btn_hold==0 
    or (btn_hold>static.hold_amt and btn_hold%static.grv_change_rate==0) then
      if(btn(1))grv-=static.turn_rate*static.time_rate
      if(btn(0))grv+=static.turn_rate*static.time_rate
    end
    btn_hold+=1
  else
    btn_hold=0
  end

  if on_ground() then
    local xvel,yvel=static.sparks_x_vel,static.sparks_y_vel
    srand(tim) 
    local dy=rnd(yvel)*sgn(py)
    local sparks_y=128-(py+64-(sgn(py)==1 and -2 or 2))
    local sparks_c=sgn(py)==1 and 12 or 8
    if rnd(static.sparks_amt)<1 then
    	local c=rnd(2)<1 and sparks_c or 6
      add(sparks,{x=static.px-2,y=sparks_y,dx=-rnd(xvel),dy=dy,c=c}) 
    end

    if btnp(4) or btnp(5) then
      
      if(btnp(5))grv=mid(sgn(py)*static.mxgrv,grv,0)

      for i=0, static.jump_sparks do
        add(sparks,{x=static.px-2,y=sparks_y,dx=rnd(xvel*2)-xvel,dy=rnd(yvel)*sgn(py),c=10})
      end
      
      pdy+=static.jmph*sgn(-py)
      prjj=0

      sfx(20,3)
      start_anim(player_anim,player_jump_anim)

      local rev=sgn(grv)==1
      local jety=62-py-(rev and 0 or 4)
      start_anim(j_anim,jet_anim,rev,static.px-4,jety)

    end
  end

  if(btnp(4))grv=0

  grv=mid(-static.mxgrv,grv,static.mxgrv)

  --update player
  pdy+=grv/static.gf
  pdy=mid(-4,pdy,4)
  py+=pdy
  local lim=mid(static.ymin,py,static.ymax)
  py=lim
  if on_ground() then
    pdy=0
    if player_anim.fin or player_anim.a.loop then
     start_anim(player_anim,player_ground_anim) 
    end
  else
    if player_anim.fin or player_anim.a.loop then
      if abs(py)<21 then
        start_anim(player_anim,player_fly_anim)
      else
        start_anim(player_anim,player_jumped_anim)
      end
    end
  end

  --advance time
  tim+=static.time_rate
  static.time_rate+=static.time_rate_accel
  real_tim+=1

  --add score
  local pts=static.frame_score
  if(on_ground())pts*=static.ground_mult
  score+=pts

  --update sparks
  update_sparks()
end


function game_draw()
  cls(0)
  draw_stars() 
  draw_planets()
  draw_ui()
  draw_path()
  draw_walls()
  draw_sparks()
  draw_player()
  draw_jets()
  draw_scenery()
  draw_checkpoint()
  if(cur_checkpoint.t==10)draw_tutorial()
  draw_score()
end 

--=========
--DIED LOOP
--=========

dead_t=nil

function died_loop_init()
	dead_t=player_die_anim.len+10
	start_anim(player_anim,player_die_anim)
  sfx(22,2) 
  current_loop=loop_enum.died
end

function died_update()
	get_walls()
	if dead_t>0 then
		dead_t-=1
	else
    if lives > 0 then
		  respawn_menu_loop_init()
    else
      game_over_loop_init()
    end
	end
end

function died_draw()
	cls(0)
	draw_stars() 
  draw_planets()
  draw_ui()
  draw_walls()
  draw_sparks()
  draw_player()
  draw_jets()
  draw_scenery()
  draw_score()
end

--=================
--RESPAWN MENU LOOP
--=================

respawn_menu_l=true
respawn_menu_t=0

function respawn_menu_loop_init()
  respawnMenu_l=true
  current_loop=loop_enum.respawn_menu
end


function respawn_menu_update()
  respawn_menu_t+=1
  get_walls()
  if btnp(0) or btnp(1) then
    respawn_menu_l= not respawn_menu_l
  end
  if respawn_menu_t>30 and btnp(5) then
    if respawn_menu_l then
      rewinding_loop_init() 
    else
      game_over_loop_init()
    end
  end
end

function respawn_menu_draw()
  cls()
  draw_stars() 
  draw_planets()
  draw_walls()
  draw_scenery()
  draw_score()
  draw_ui()
  local c=title_clr[((respawn_menu_t/6)%#title_clr)\1+1]
  rectfill(40,62,88,82,0)
  print('respawn?',48,64,14)
  -- print('(score-100)',42,72,8)
  print('yes',45,75,c)
  print('no',74,75,c)
  if respawn_menu_l then
    rect(43,73,57,81,c)
  else
    rect(72,73,82,81,c)
  end
end


--===========
--REWINDING LOOP
--===========

rewind_start_time=nil
rewind_start_score=nil
rewind_t=nil

function rewinding_loop_init()
  cur_checkpoint_score=max(0,cur_checkpoint_score-static.rewind_penalty)
	rewind_t=static.rewind_len
	rewind_start_time=tim
  rewind_start_score=score
  sparks={}
	current_loop=loop_enum.rewinding
	pal(0,7,1)pal(7,0,1)pal(12,0,1)pal(8,0,1)
end

function rewinding_update()
	get_walls()
	tim=ease(rewind_start_time,cur_checkpoint.t*10,rewind_t,static.rewind_len)
  score=max(0,ease(rewind_start_score,cur_checkpoint_score,rewind_t,static.rewind_len))
  if rewind_t>0 then
  	rewind_t-=1
  else
		spawning_loop_init()
  end
end

function rewinding_draw()
	cls(0)
  draw_stars() 
  draw_planets()
  -- draw_ui()
  draw_walls()
  draw_scenery()
  draw_score()
end


--=============
--SPAWNING LOOP
--=============

spawn_t=nil

function spawning_loop_init()
	spawn_t=player_spawn_anim.len-1
	tim=cur_checkpoint.t*10
  lives-=1

	if cur_checkpoint.y==0 then
		py=38
		grv=static.mxgrv
		prjj=static.jmph*sgn(-py)
	elseif cur_checkpoint.y==7 then
		py=-38
		grv=-static.mxgrv
		prjj=static.jmph*sgn(-py)
	else
		py=35-cur_checkpoint.y*10
		grv=0
		prjj=0
	end

	pdy=0
	prjg=grv/static.gf
	start_anim(player_anim,player_spawn_anim)
	current_loop=loop_enum.spawning
end

function spawning_update()
	get_walls()
	if spawn_t>0 then
		spawn_t -=1
	else
		game_loop_init()
	end
end

function spawning_draw()
	cls(0)
	draw_stars() 
  draw_planets()
  draw_ui()
  draw_walls()
  draw_player()
  draw_jets()
  draw_scenery()
  draw_score()
  pal(7,7,1)pal(12,12,1)pal(8,8,1)pal(0,0,1)
end


--=========
--GAME OVER LOOP
--=========

game_over_t=nil

function game_over_loop_init()
  game_over_t=0
  current_loop=loop_enum.game_over
end

function game_over_update()
  game_over_t+=1
  if game_over_t>60 then
    if btnp(4) or btnp(5) then
      title_loop_init()
    end
  end
end

function game_over_draw()
  cls()
  print('game over',46,58,8)
  print('score:'..score\1,46,64,6)
  if(game_over_t>60)print('press any button to restart',12,80,6)
end


--=================
--DRAWING FUNCTIONS
--=================


function draw_stars()
  local s_tim=tim*static.star_speed
  for x=s_tim\1-400,s_tim do
    srand(constant.seed+x)
    if rnd(40)<1 then
      local sx=s_tim-x
      sx=c_val(sx,400,.75,0,0)
      sx=128-128*sx
      local y=rnd(128)\1
      local ylim=gety(sx)
      if mid(ylim-1,y,128-ylim)==y then
        pset(sx,y,7)
      end
    end
  end
end

function draw_planets()
  local p=nil
  for x=0,#constant.cchart-80,10 do
    local y=constant.cchart[x+80]
    if(p) then
      line(p.x,p.y,x/10,y,(current_loop==loop_enum.rewinding and 12 or 8))
      line(p.x,128-p.y,x/10,128-y,12)
    end
    p={x=x/10,y=y}
  end
  p=b
end

function draw_ui()
  local off=grv*4
  off=grv<0 and max(off,-11) or min(off,11)
  if(grv~=0)rectfill(119,64,121,64-off,grv>0 and 12 or 8)
 -- print(abs(grv),119,62+numoff-grv*5,15)
  local g='grav'
  for i=1,#g do
    print(sub(g,i,i),123,47+6*i,10)
  end
  rect(117,51,127,77,2)
  spr(26,0,0)
  print('x '..lives,11,1,14)
end

function draw_path()
  local pty,ptd,g,c=64-py,pdy,grv/static.gf
  if not on_ground() then
    c=15
    prjj*=.9
  else
    v_j_dist=0
    c=5
    prjj+=(static.jmph*sgn(-py)-prjj)/4
  end
  ptd+=prjj
  prjg+=(g-prjg)/4
  local dist=v_j_dist
  for ptx=static.px,127,static.time_rate do
    dist+=sqrt(static.time_rate^2+abs(ptd)^2)
    n_pty=pty-ptd
    local lim=gety(ptx)
    if(mid(128-lim,n_pty,lim)~=n_pty)break;
    if (dist-real_tim*0.75)%10<3 then
      line(ptx-1,pty,ptx,n_pty,c)
    end
    pty=n_pty
    ptd+=prjg  
  end
  v_j_dist+=abs(pdy)
end

function draw_walls()
  for w in all(walls) do
    srand(w.x+.1*w.y)
    local spr_c=spr_coords(w.spr)
    if(w.c_swp)pal(8,12)
    sspr(spr_c.x,spr_c.y,8,8,w.x,w.y,w.sz,w.sz)
    pal(8,8)
  end
  walls={}
end

function draw_player()
  local x=static.px-4
  local y=60.5-py
  local r=player_anim.a~=player_fly_anim and sgn(py)==1 or false
  draw_anim(player_anim,r,x,y)
end

function draw_jets()
  if not j_anim.fin then
    draw_anim(j_anim)
  end
end

function draw_scenery()
  local start=tim-100
  local rmnd=static.scenery_interval-start%static.scenery_interval
  start+=rmnd
  for x=start,tim,static.scenery_interval do
    srand(constant.seed+x)
    local r=rnd(15)\1
    if r<=1 then
      local spr=static.scenery_spr[(rnd(5)+1)\1]
      local spr_c=spr_coords(spr)
      local xf=c_val(tim-x,100,.75,0,0)
      local sz=max(c_rate(xf,2)*10,2)
      local hf=c_rate(xf,1)
      hf=min(hf,.8)
      local sx=127-127*xf
      local h=max(2,((5+rnd(17))*hf)\1)
      local ylim=gety(sx)
      if r==1 then
        pal(8,12)
        ylim=127-ylim-sz/2
        h=h*-1
      end
      sspr(spr_c.x,spr_c.y,8,8,sx,ylim+h,sz,sz,false,r==1)
      pal(8,8)
    end
  end
end

function draw_checkpoint()
  if(check_txt>0)draw_text('checkpoint!',14,false)    
end


function update_sparks()
  -- printh(#sparks)
  for s in all(sparks) do
    s.dx-=static.sparks_x_drag
    s.dy-=grv/static.gf
    s.x+=s.dx
    s.y+=s.dy
    local y=gety(s.x)
    if s.x<0 or mid(y,s.y,128-y)~=s.y then
      del(sparks,s)
    end
  end
end

function draw_sparks()
   for s in all(sparks) do
    -- printh('x='..s.x..' y='..s.y)
    pset(s.x,s.y,s.c)
   end
end

function draw_tutorial()
  print('🅾️',0,108,7)
  print('    : jump',4,108,7)
  print('❎',0,114,7)
  print('    : high jump',4,114,7)
  print('⬅️/➡️',0,120,7)
  print(' : change gravity',16,120,7)
end

function draw_score()
	print('score:'..score\1,48,0,7)
end

--====================
--MAP-READING FUNCTION
--====================

function get_walls()
  
  local g_chunks=constant.gen_chunks
  local ti=(tim\10)
  for xi=max(1,ti-(static.screen_time\10)),ti do
    local xf=c_val(tim-xi*10,static.screen_time,.5,.2,.3)
    local x=127-xf*127
    if x>-8 then

      local sz=c_rate(xf,3)*8
      local hf=c_rate(xf,8)
      local y=gety(x)
      
      local chunk_t,chunk_r
      for i=xi,0,-1 do
        local c=g_chunks[i]
        if c then
          chunk_t=c.t+(xi-i)
          chunk_r=c.r
          break
        end
      end

      local mx=chunk_t%128
      local my=chunk_t\128*8
      local conn=constant.conn_walls[xi]
      local nrm_queue=conn and copy(conn.b) or {}
      local rev_queue=conn and copy(conn.t) or {}

      for yi=0,7 do
        local s=mget(mx,my+yi)
        local yyi=chunk_r and 7-yi or yi
        if(s==1)add(chunk_r and rev_queue or nrm_queue,yyi) 
        if(s==2)add(chunk_r and nrm_queue or rev_queue,yyi)
      end

      function add_walls(q,r)
        for wy in all(q) do
          local yy
          local yoff=wy*10
          local yy=r and y-(10+yoff*hf) or 127-y+(74-yoff)*hf  
          srand(xi+.1*wy)
          add(walls,{x=x,y=yy,sz=sz,spr=3+rnd(7)\1,c_swp=not r})
        end
      end

      add_walls(nrm_queue,false)
      add_walls(rev_queue,true)

    end
  end
end



--==========
--ANIMATIONS
--==========

function start_anim(a_obj,a,r,x,y)
 	if(a_obj.a==a and a_obj.a.loop)return
  a_obj.f=0
  a_obj.a=a
  a_obj.fin=false
  a_obj.x=x
  a_obj.y=y
  a_obj.r=r
end

function draw_anim(a_obj,r,x,y)
	if(a_obj.fin)return
	if(x)a_obj.x=x
	if(y)a_obj.y=y
	if(r)a_obj.r=r
	local a=a_obj.a
	local rate=a.len/#a.sprites
	local s=a.sprites[a_obj.f\rate+1]
	local c=spr_coords(s)
	sspr(c.x,c.y,8,8,a_obj.x,a_obj.y,8,8,false,a_obj.r)
	a_obj.f+=1
	if a.loop then
		if(a_obj.f==a.len)a_obj.f=0
	else
		if(a_obj.f==a.len)a_obj.fin=true
	end
end

function draw_text(txt,clr,perm)
  if txt_cor==nil then
    txt_cor=cocreate(anim_text)
  end
  coresume(txt_cor,txt,clr,perm)
end

function anim_text(txt,c,perm)
	local max_t=#txt+20+30
	local t=max_t
	while t>0 do
		local fct=1-t/max_t
		local lim=flr(fct*max_t)
		local ln=0
		local col=0
		for i=1,lim do
		  local char=sub(txt,i,i)
		  if char=='$' then
		   	ln+=1
		   	col=0
		 	else
		  	local drft=1-(lim-i)/20
		  	local dy=max(0,drft*5)
		  	if(dy>0)dy+=-(sin(drft)+.5)*6
	    	local x=col*4+44
	    	local y=ln*8+60
	    	print(char,x,y+dy,c)
	    	col+=1
		  end
		end
		t=t>=0 and t-1 or t
		if(perm)t=max(t,1)
	 	yield()
	end
end

player_ground_anim={
	len=30,
	loop=true,
	sprites={10,11,12,13,14,15}
}
player_jumped_anim={
	len=1,
	loop=true,
	sprites={26}
}
player_jump_anim={
	len=20,
	loop=false,
	sprites={26,27,28,27,26}
}
player_fly_anim={
	len=30,
	loop=true,
	sprites={42,43,44,45,46,47}
}
player_die_anim={
	len=40,
	loop=false,
	sprites={58,59,60,61,62,63}
}
player_spawn_anim={
	len=60,
	loop=false,
	sprites={63,62,61,60,59,58}
}
jet_anim={
	len=12,
	loop=false,
	sprites={18,19,20,21,22}
}

--====================
--CURVE/DATA FUNCTIONS
--====================

function c_val(t,len,lim,srate,buf)
	local a=1/(2*lim-lim^2)
	if t/len<=buf then
		return (t/len)*srate
	else
    local x=(t-len*buf)/(len-(len*buf))
    local y0=srate*buf
    if x>lim then
      return y0+2*a*lim*x-a*lim^2
    else
      return y0+a*x^2
    end
  end
end

function c_rate(f,inc)
	return min(f*inc,1)
end

function gety(x)
	x=flr((x+8)*10)
	return constant.cchart[x]
end

function on_ground()
 return py==static.ymin or py==static.ymax
end

function bez_point(x1,y1,x2,y2,h2,d2,h1,d1,t)
	local a=atan2(x2-x1,y2-y1)
	local d=sqrt((x2-x1)^2+(y2-y1)^2)
	h1,d1,h2,d2=h1*d,d1*d,h2*d,d2*d
	local s,c=cos(a),sin(a)
	local xo,yo=c*d1-s*h1,s*d1+c*h1
	local nxo,nyo=-c*d2-s*h2,s*d2-c*h2
	local c1x,c1y,c2x,c2y=x1-nxo,y1-nyo,x2+xo,y2-yo
	local x=(((1-t)^3)*x1)+(3*t*((1-t)^2)*c1x)+(3*(t^2)*(1-t)*c2x)+((t^3)*x2)
	local y=(((1-t)^3)*y1)+(3*t*((1-t)^2)*c1y)+(3*(t^2)*(1-t)*c2y)+((t^3)*y2)
	return {x=x,y=y}
end  

function spr_coords(s)
	return{x=s%16*8,y=s/16\1*8}
end

function ease(n,x,t,ln)
	t=t/ln*2
	local c=n-x
	if t<1 then
		return (c/2*t^2+x)\1
	else
		return (-c/2*((t-1)*(t-3)-1)+x)\1
	end
end

--==============
--UTIL FUNCTIONS
--==============

function add2(obj,k,v)
	if obj[k] then
		add(obj[k],v)
	else
		obj[k]={v}
	end
end

function has(obj,val)
	for v in all(obj) do
		if(v==val)return true
	end
	return false
end

function copy(tbl)
	local ret={}
	for i=1,#tbl do
		ret[i]=tbl[i]
	end
	return ret
end

function reverse_set(s)
	local ret={}
 	for i=#s,1,-1 do
  	add(ret,7-s[i])
	end
	return ret
end





__gfx__
0000000088888888cccccccc00888800008888000088880000888800008888000088880000888800000000000000000000000000000000000000000000000000
0000000088888888cccccccc08818180081111800818818008888880088888800818888008811880000000000000000000000000000000000000000000000000
0070070088888888cccccccc88881818811111188811118811111880888118888181111888188188000e4000000e4000000e4000000e4000000e4000000e4000
0007700088888888cccccccc88888188888888888181181888881188881111888181881881811818006ee600006ee700007ee700007ee700007ee700007ee600
0007700088888888cccccccc88888818888888888181181811188111881111888181181881811818006ee600007ee600007ee700007ee700007ee700006ee700
0070070088888888cccccccc88888888811111188811118888118888888118888188881888188188007777000077760000776600007667000066770000677700
0000000088888888cccccccc08888880081111800818818008811110088888800811118008811880000000000000000000000000000000000000000000000000
0000000088888888cccccccc00888800008888000088880000888800008888000088880000888800000000000000000000000000000000000000000000000000
aaaaaaaa000000000000000000000000000000000000000000000000eeeeeeeedddddddd00088000000000000000000000000000000000000000000000000000
aaaaaaaa000000000000000000000000000000000000000000000000eeeeeeeedddddddd08800800000e4000000e4000000e4000000800000000000000000000
aaaaaaaa000ee0000000000000000000000000000000000000000000eeeeeeeedddddddd80088088007ee700007ee700007ee700008880000008000000000000
aaaaaaaa00e8ce00000000000000000000000000000000000a0000a0eeeeeeeedddddddd08800800007ee700007ee700007ee700080808000800800800000000
aaaaaaaa00ec8e000000000000000000000000000a0000a000000000eeeeeeeedddddddd8008808800e0e00000e0e00000e0e000000800000080808000000000
aaaaaaaa000ee00000000000000000000a00009000000000a000000aeeeeeeeedddddddd088008000077770000e0e00000e0e000008880000008880000000000
aaaaaaaa00000000000000000a0000a0a6000069a600006a00000000eeeeeeeedddddddd80000088000000000077770000e0e000080808000000000000000000
aaaaaaaa0000000000a66a0000666600066666606666666660600606eeeeeeeedddddddd00000000000000000000000000777700000800000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000080800007777000067770000667700007667000077660000777600
00000000000000000000000000000000000000000000000000000000000000000000000000080800006ee600006ee700007ee700007ee700007ee700007ee600
00000000000000000000000000000000000000000000000000000000000000000000000000800080006ee600007ee600007ee700007ee700007ee700006ee700
00000000000000000000000000000000000000000000000000000000000000000000000000800080007777000077760000776600007667000066770000677700
00000000000000000000000000000000000000000000000000000000000000000000000008080008000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000080008008000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000070070000000000e0e00e0ee000000e
000000000000000000000000000000000000000000000000000000000000000000000000008880000000000000700700000000000ee00ee00000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000080808000077770007eeee7070eeee070e0000e0e000000e00000000
00000000000000000000000000000000000000000000000000000000000000000000000000888000007ee70000eeee0000e00e00000000000000000000000000
00cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc0008080800007ee70000eeee0000e00e00000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000008880000077770007eeee7070eeee070e0000e0e000000e00000000
000000000000000000000000000000000000000000000000000000000000000000000000080808000000000000700700000000000ee00ee00000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000070070000000000e0e00e0ee000000e
000fffffff0000ffffff000fffffff00000fffffff0000fffffff0000000000ffffff00000000000000000000000000000000000000000000000000000000000
00fffffffff00ffffffff00ffffffff000fffffffff00fffffffff00000000ffffffff0000000000000000000000000000000000000000000000000000000000
00fff000fff00ff0000ff00fff0000ff00fff000fff00fffffffff00000000fff000ff0000000000000000000000000000000000000000000000000000000000
00ff00000ff00ff0000ff00ff00000ff00ff00000ff00000fff00000000000ff0000ff0000000000000000000000000000000000000000000000000000000000
00ff00000ff00ff0000ff00ff0000fff00ff00000ff00000fff00000000000ff000fff0000000000000000000000000000000000000000000000000000000000
00ff00000ff00ff000fff00ffffffff000ff00000ff00000fff0000fffff00ffffffff0000000000000000000000000000000000000000000000000000000000
00ff00000ff00ff00fff000ffffffff000ff00000ff00000fff0000fffff000ffffff00000000000000000000000000000000000000000000000000000000000
00ff00000ff00ffffff0000fff0000ff00ff00000ff00000fff0000fffff00fff000ff0000000000000000000000000000000000000000000000000000000000
00ff00000ff00fffff00000ff00000ff00ff00000ff00000fff00000000000ff0000ff0000000000000000000000000000000000000000000000000000000000
00ff00000ff00ff0fff0000ff00000ff00ff00000ff00000fff00000000000ff0000ff0000000000000000000000000000000000000000000000000000000000
00fff000fff00ff00fff000ff0000fff00fff000fff00000fff00000000000ff000fff0000000000000000000000000000000000000000000000000000000000
00fffffffff00ff000fff00fffffffff00fffffffff00000fff00000000000ffffffff0000000000000000000000000000000000000000000000000000000000
000fffffff000ff0000ff00ffffffff0000fffffff000000fff000000000000ffffff00000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00888888888888888888888888888888888888888888888888888888888888888888880000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00202020202020000000000000000000000020202020000020202020202000002020202000000000000000000000002000000000810000000000000000000000
00000000000000000000000000000000002020000020200000008100002020202020202000000000000000000000000000200000000000000020000000810000
71000000000020200000000000202020007100000000202000000000000020200000000081000000000000000000002000000010000000000000000000000000
00000000000000000000000000000000000000000000000000008100000000000000002000000000000000000000000000200000000000000020000000810000
71000000000000202000000020200000817100002000000000100000200000000010000081002020202020202020202000000010000000000000000000000000
00000000000000000000000000000020200000202000002000100000000000000000202020000000000000000000000000200000000000000020000010000000
71010000000000002020002020000000817100000000000000100000000000000010000081710000002000000000002000001000000000000000000000000000
00000000000000002020202020000000000000000000002000100000000000000020202020200000000000000010100020200000000020202020000010000000
71000000101000000020202000000000817101000020000000000000002000000000000081710100000000001000000000001000000000000000002020202020
20200000000000710000000000200000002020000020002000100000000000000000000000008100202020001010000000000000000020000000000010000000
71000010101010000000200000001000817100000020000010000000002000001000000081001010101010101010101010100000000020202020202000000000
00202020202000710000000000000000000000000020000000100000200000000010101010100071000000000010000000008100202020000000101010000000
71001010000010100000000000101010007100000000000000001010000000000000000081000000000000000000000000000000007100000000000000000010
00000000000081710000202000000000000010101010101010100071000000001010000000000071000000000010000000008171000000000000100000000000
00101000000000101010101010100000000010101010101010100000101010101010101000000000000000000000000000000000007101001000000010101010
00000010000081710100000000001010101010000000000000000071010000101000000000000071010000000010000000008171010010101010100000000000
00000000000000000020000000000000002000002020000000000000000000200000000000200000000000000000000000000000810000202000000020200000
00000000002000000000000000200000000000200000202020202020202020202020202020202020202020000000000000000000000000000000000000000000
00000000000000000020000000000000002000710020000000202000200000200000000000200000000000000000000000000000810020200000100000202000
00000000002000000000000000200000000000200071000000000000200000000000002000000000000020000000000000000000000000000000000000000000
00000000000000000020000000000000002000710020202020200000200000008100000000202020202020202020202020000010000020000010101000002020
00000000002000000000000000200000000000200071000000200000200000000000002000000000000020000000000000000000000000000000000000000000
00000000000000000020000000000000002000710000000000000000200000008100000000000000000000000000002000000010007100001010001010000020
20000000002000000010000000200000000000008171000000200000000000001000002000000020000000810000000000000000000000000000000000000000
00202000001000002020200000100000202000710100000000000000100000008100000000000000000000001000000000001010007101101000000010100000
20200000002000000010000000000000100000008171010000200000100000001000000000000010000000810020202020202020202020202020202000000000
71000000001000000000000000100000000081710010101010100000100000008100202020202020200000101010101010101000000010100000000000101000
00202000710000000010000000000000100000100071000000000000100000001000001000000000000010007100002000000000000000000020000081000000
71000000001000000000000000100000000081710010000000101000100000100071000000000020000000100000000000000000000000000000000000001010
00002000710000000010000000000000100000100071000000000000100000000000001000000000000010007100000000000000100000000000000081000000
71010000001000000000000000100000000081001010000000000000000000100071010010000000000000100000000000000000000000000000000000000010
10000081710100000010000000000000100000100000101010101010101010101010101010101010101010007101001000000010101000000010000081000000
00202020202020202000002020202020202020000020202020202020200000000000000000000081000000000000000000008100000000002000000000000020
00008100200000000000000000000000000000200000000000002000002000000000000000000000000000000000000020202020202020202020202020000000
71000000000000000081710000002020000000817100000000000000008100000000000000000081002000200020002000200000000000002000000000100000
00100000200000000000000000000020000000200000000000002000002000000000000000000000000000000000007100202000000000000020200020200000
71000000202000000081710000202020200000817100000020200000008100000020000000000081710000000000000000100000000000002000000000101010
10100000200000000000000000000020000000200000000000002000002000000000000000000000000000000000007100101000002020000010100000008100
71000020202020000081710100000000000000817100002020202000008100202020000010000000710000000000000010100000000000002000000000100000
00000000200000000000002020202020008100200000000000002000002000000000000000000000000000000000007101000000001010000000000000008100
71010010101010000081710000101010100000817101000000000000008100000020000010101000710100000000101010000000000000002000000000100000
00000000202020202020202000000000008100202020002020002000002000000000000000000000000000000000007100202000000000000020200000008100
71000000101000000081710000001010000000817100001010101000008171000000000010000000710000001010100000000000202020202000000000100000
00000071000020200000000000001010100071000000001000000081002020202020202020000020202020202020007100101000002020000010100000008100
71000000000000000081710000000000000000817100000010100000008171000000000000000000001010101000000000000000200000002000000000100000
00000071010000000000101010101000000071000000001000000081710000000000000020202020000000000000817100000000001010000000000010100000
00101010101010101000001010101010101010000010101010101010100071010000000000000000000000000000000000000071010010000000000000100000
00000071000010101010100000000000000071010000001000000081710100101010100000000000001010101000810010101010101010101010101010000000
00202020202020202020202020202020000000000000000081000000000000000000000000000000000000000000000000000000000000002000000000000000
00000000000000000000000000000000000081002020202020202020000081002000000000000000000000000000200000810020202020202020202020200000
71000000200000002000000020000000810000000000000081000000000000000000000000000000000000000000000000202020202020002000002020202020
20202020202020202020200000202000202000710020000000200000001000002000000000000000000000000020200000817100200020002000200020008100
71002000000020000000200000002000810000202020001000000000002020202020202000000000000000000000000020200000000020202000710000200000
00200000000020000000008171000000002000710000002000000000101000002000000020202020200000002020000010007100200000002000000020008100
71010000200000002000000020000000810000000000001000000000002000000000002000000000000000000000000020000000100000000081710000200000
00200000000020000000008171010000002000710020000000200010100000002000002020000000202000202000001010007101000020000000200000008100
71001000000010000000100000001000810020202000101000000000002000000000002000000000000000000000202020000000100000000081710100000010
00000000100000001000008171000000001000710100002000000010000000002000202000001000002020200000101000007100100000001000000010008100
71000000100000001000000010000000817100000000001000002020202000001000002020000020202020200071000000000000101010101000710000000010
00000000100000001000008171000000001000710020000000101010000000002020200000101010000020000010100000007100000010001000100000008100
71001000000010000000100000001000817100000000001000710000000000001000000000817101000000008171000000000000100000000000001010101010
10101010101010101010100000101000101000710000000010100000000000710000000010100010100000001010000000007100100010001000100010008100
00101010101010101010101010101010007101000000001000710100100000001000000000817110101010100071010000000000100000000000000000000000
00000000000000000000000000000000001000001010101010000000000000710100001010000000101010101000000000000010101010101010101010100000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc0000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000fffffff0000ffffff000fffffff00000fffffff0000fffffff0000000000ffffff00000000000000000000000000000000
00000000000000000000000000000fffffffff00ffffffff00ffffffff000fffffffff00fffffffff00000000ffffffff0000000000000000000000000000000
00000000000000000000000000000fff000fff00ff0000ff00fff0000ff00fff000fff00fffffffff00000000fff000ff0000000000000000000000000000000
00000000000000000000000000000ff00000ff00ff0000ff00ff00000ff00ff00000ff00000fff00000000000ff0000ff0000000000000000000000000000000
00000000000000000000000000000ff00000ff00ff0000ff00ff0000fff00ff00000ff00000fff00000000000ff000fff0000000000000000000000000000000
00000000000000000000000000000ff00000ff00ff000fff00ffffffff000ff00000ff00000fff0000fffff00ffffffff0000000000000000000000000000000
00000000000000000000000000000ff00000ff00ff00fff000ffffffff000ff00000ff00000fff0000fffff000ffffff00000000000000000000000000000000
00000000000000000000000000000ff00000ff00ffffff0000fff0000ff00ff00000ff00000fff0000fffff00fff000ff0000000000000000000000000000000
00000000000000000000000000000ff00000ff00fffff00000ff00000ff00ff00000ff00000fff00000000000ff0000ff0000000000000000000000000000000
00000000000000000000000000000ff00000ff00ff0fff0000ff00000ff00ff00000ff00000fff00000000000ff0000ff0000000000000000000000000000000
00000000000000000000000000000fff000fff00ff00fff000ff0000fff00fff000fff00000fff00000000000ff000fff0000000000000000000000000000000
00000000000000000000000000000fffffffff00ff000fff00fffffffff00fffffffff00000fff00000000000ffffffff0000000000000000000000000000000
000000000000000000000000000000fffffff000ff0000ff00ffffffff0000fffffff000000fff000000000000ffffff00000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000888888888888888888888888888888888888888888888888888888888888888888880000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000fffff0000000ff0fff000000fffff000000fff00ff000000ff0fff0fff0fff0fff0000000000000000000000000000000
000000000000000000000000000000ff0f0ff00000f0f0f0f00000ff000ff000000f00f0f00000f0000f00f0f0f0f00f00000000000000000000000000000000
000000000000000000000000000000fff0fff00000f0f0ff000000ff0f0ff000000f00f0f00000fff00f00fff0ff000f00000000000000000000000000000000
000000000000000000000000000000ff0f0ff00000f0f0f0f00000ff000ff000000f00f0f0000000f00f00f0f0f0f00f00000000000000000000000000000000
0000000000000000000000000000000fffff000000ff00f0f000000fffff0000000f00ff000000ff000f00f0f0f0f00f00000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0001020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000001800020202020202020202000002020000000000000000020200000000000002020200000000000200000000000000020200000000001817000000000000000017000000000200000018000202000000000000000000000000
0002020202020202020202020000000000000000000000000000000000000000000000000000001800000002000000020000181700020200000000000017000202020000020202000018000000000200000000000202020000000000001817000002000000001817000000000200000018000002020000000000000000000000
0000000000000000000000000000000000000000000000020202020202020202000010000000001817000000000000000000181700000202000000000017000000020202020000000018000000000202020202020200000000000000001817000002000000001800000000000200000018000000020202020200000000000000
0000000000000000000000000000020202020202020000000000000000000000000000000000000017100000000200000000181700000002020000000017000000000000000000000018000000000000000000000000000000000101010017000002000000001800000000000000000018000000000000000018000000000000
0000000000000100000000000000000000000000000000000000000000000000000000000100000017000000000000000000180000000000020200000017100000000000000000000018001000000000000000000000000001010100010017100001000000001800100000000000000018001000000000000018000000000000
0000000000010101000000000000000000000000000000000000000100000000181700000100000017000100000000000100180010000000000202000017000000010101010000000018170000000000000101010101010101000000010017000001000000001800000000000100000018170000000001010100000000000000
1700000001010001010000001817000000010000001817000000010101000000181700000100000000000000000100000000180000000000000002020017000101010000010101000018170000000001010100000000000000000000010017000001000000001817000000000100000018170000000101000000000000000000
1710000101000000010100001817100001000100001817100001010001010000181700000100000000010101010101010101000000000000000000001800010100000000000001010100170000000001000000000000000000000000010117000000000000001817000000000100000018170000010100000000000000000000
0002020200000002020200170000000200000000000000020200000000000000001710000000000200000018171000000000020202000000001800000202020202020202020202020202020202020000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000018
0000000202000202000000170000000202000000000017000202000000000202001700000000000000000018170000000000000200000000001800170000000000000200000000000000000000001800020202020202020200000000000000180000000000000000000000000000000000000000000000000000000000000018
0000000002000200000000171000000002020000000017000002020202020200001700000000010101010100170000000000000000000000001800170000000000000000000000000000000000001817000000000000000200000000000101000000000000000002020202020202020202020202000000000000000000000018
0000000002000200000000000000000000020200000017000000000000000000181700000001010000000000170000000101010101010101010000170000000002000000000000000100000000001817000000000000000200000000010100000000000000000202000000000002000000000000180002020000000101010100
0000000002020200000000000101010000000202020017100000000000000000181700000101000000000000170000010100000000000000000000171000000000000000020000000000000001001817100000000000000000000001010000000002020202020200000000000000000000000000180000000000000001000000
1700000000000000000018000000010100000000000017000001010101010100000001010100000000000000000101010000000000000000000000170000000000000000000000000000000000001817000000000000000000000001000000001700000000000000000001000000000000010101001700000000000001000000
1700000000000000000018000000000101000000000017000101000000000101000000000000000000000000000000000000000000000000000000170000000000000000000000000000010000001800010101010101010101010101000000001710000000000000000101010000000101010000001700000000000001000000
1710000000010000000018000000000001010000001800010100000000000000000000000000000000000000000000000000000000000000000000000101010101010101010101010101010101010000000000000000000000000000000000001700010000000000010100010101010100000000001710000000000001000000
0002020202020202020202020202020200000000000000000000000002000000020000000000000200000000000002020202020202000000000000000000000000000000000000000002000000000000000000001800000000000000000000000000000000000000000002020202020202020202020202020200000000000000
0000000000020000000200000002000000000000000000000000000002000000020000000000000200000202020202000000000002000002020202020202020000000000000202020202000000010000000000001800000000000000000000000000000000000000000000000002000000020000000000000200000000000000
0000000000020000000000000002000018000000000000000000000002000000000000020200000018170000000200000000000002000002000000000000020200000000000200000000000001010000010101010000000000000000000000000000000000000000001700000002000000020000000000000018000000000000
1700000000000000000000000000000018000202000000000000000202000017000000020200000018170000000200000000000002000002000000000000000018000000000200000000000000000000010000000000000000000000000002020202020000000000001700000002020000000000020200000018000000000000
1710000000000000000100000000000018000000000001010100000000000017100000010100000018171000000000000001000000181700000000010000000018000202020200000202000000000000010000000000020202020202020202000000020202020202001700000001010000000000010100000018000000000000
0000000000010000000100000001000018170000000000010000000000180000000000010100000018170000000000000001000000181700000000010101010100170000000000000200000001010101010000000017000000000000000000000000000002000000181710000000000000010000000100000018000000000000
0000000000010000000100000001000000170000000000010000000000180000010000000000000100000101010101010101000000181700000000010000000000170000000000000000000001000000000000000017000000000000000000000100000000000000180000000000000000010000000100000018000000000000
0001010101010101010101010101010100171000000000010000000000180000010000000000000100000000000000000001000000181710000000010000000000171000000000000000000001000000000000000017100000000101010101010101010101010101000001010101010101010101010101010100000000000000
0002020202020202020000000000020202020202020000000000000000000202000018000000000000000000000018000000000202020202020202020202000000000000000000000000000000000000020000000002000000000000000000000000000002000200020202020000000002020202020202020202020200000018
1700000000020000000000010000000002000000020000000000000000020200000018000000000000000000000018000000000200000000000000000002000000000000000000000000000000000000020000000002000000000000000000000000000002000200020000020200000000000200000000000000000000000018
1700000000020000000000010000000002000000020000020202000002020000000100000000000202020000000100000000000200000000000000000002000000000002020200000101010101000002020000020202020202020200000000000001000000000200000000000202001700000000000000000100000200000100
1700000000020000000000010000000002000000001817000002020202000000010100000000000000000000010100000000000200000000000000000002000000001700000000000000010000000000000000000000020000000018000000000001000000000000000000000000181700000000000200000000000000000100
1700000000020000000000010000000002000000001817100000020200000001010000000000000000000000010000000000000200000000010000000002000000001710000000000000010000000000000000000000020000000018000200000001000001000000010000000000181710000000000100000000000000010100
1710000000020000000000010000000000000000010017000000000000000101000000000202020000010101010000000202000200000000010000000002000202000001010100000101010101010101010000020202020200000100170000000101000001000100010101010101001700000000000000000200000001010000
1700000000020000000000010000000000000000010000010000000000010100000000170000000000000100000000170002020200000000010000000002020200180000000000000000010000000000000000000000000000000100170000000100000001000100010000000000000000000100000000000000000101000000
0001010000000000010101010101010101010101010000010101010101010000000000171000000000000100000000171000000000000000010000000000000000180000000000000000010000000000000000000000000000000100171000000100000001000100010000000000000001010101010101010101010100000000
__sfx__
011000000c1150c1150f115131150c1150c1150f115131150f1150f11513115141150f1150f115131151411512115121151411516115121151211514115161150f1150f1151211513115121150f1150f1150d115
01100000180151801518005180152201522015180051b01522015200151f0151b0151b015180051f015200152701527015240052701522015220151800522015250152501525015240152001520015200151e015
0110000018510185102051022510205101b510195101851018510185102051022510205101b51019510185101b5101b5102051022510205101b510195101b5101d5101d5102051022510205101b510195101b510
01100000005233c5033c6150050000523005003c61500500005233c5033c6150050000523005003c61500500005233c5033c6150050000523005003c61500500005233c5033c6150050000523005003c61500500
01100000005233c5033c6150052300523005233c61500500005233c5033c6150050000523005233c61500500005233c5033c6150050000523005233c61500523005233c5033c6150050000523005233c61500523
010800000c5400c54010540105401154011540105401054011540115401554015540185401854018540185401053010530105300c500135301350013530185000c5300c5300c5300c53018530185301853018530
010800001d5351d5351c5351c5351a5351a53518535185351c5351c5351f5351f535185351853518535185351353013530135300c50018530115001853018500105301053010530105300c5300c5300c5300c530
010a00001851018510185101c5101c5101c5101f5101f5101f5101c5101c5101c5101f5101f5101f5101f5102151021510215101c5101c5101c5101f5101f5101d5101d5101d5101c5101c5101c5101c5101c510
0001000020640206402064021640216403a340393303533031330303302f3302e3102c3102a310263101f3101b31018310143100f3100b3100000000000000000000000000000000000000000000000000000000
0002000005620026200f62008620156201a6200f32026420173202142012320264201a320304201c32034420253202f4201630008600086000760007600076000960006600056000560005600056000360002600
011000000c7300c7001d7301c7301c7001c7001f7301d7000c7300c7001d730147301c7001d700137301c7300c7300c7001d7301c7301c7001c700207301d7000c7300c7001d730147301c7301d7301473013730
0110000024115181151f115201151c1151c1151f1152211520115221151f1151f1151c1151c11519115181151c1151c1151d1151f1151d1151d1151d115201151f1151f1151f11520115201151f1151d1151c115
0110000007523376152e5100752337615075232e5103761507523075232c5100752337615075232c51007523075233761529510075233761537615295103761507523376152b5100752337615376153761537615
0110000024515295152c5152e515245152b5152e51530515245152b5152e51530515245152b5153051531515285152b515305153151528515295152e51530515295152b5152e515305152b515295152851500000
00010000056102f6102161002610386101b610056102d6103a6103761010610216102e6103c6102661009610316103b6102061024610146100a6103e610246101e6102d6103e6101c61009610386103461002610
01010000000003a0503a0503905000000380500000000000350503d05000000320500000039050000002d0500000036050000003405027050330500000022050000001f050290501a050150500d0500805003050
0110000007523376152e5100752337615133002e5102e51507523133002c5100752337615075232c5102c515075233760029510075233761537600295102951507523376152b5100752337615376002b51037515
000200002401025010290102e02034020350302b6302b6302c6302c6303c7103c7103c7103c7103c7103c7103c7103c7103c7103c7103c7103c7103c7103c7103c7103c7103c7103c7103c7103c7103c7103c700
011000001f7151f715187051d7151b7151b715187051b7151f7151f7151b7151b71518715187151b7151b7152071520715187052271520715207151870522715257152571525715247152071520715207151e715
011000000c1150c1150f115131150c1150c1150f115131150f1150f11513115141150f1150f11513115141150c1150c1150f115131150c1150c1150f115131150f1150f1151211513115121150f1150f1150d115
000100000b6300b6300b6301253012530125301253012530125301253012030120301303016030180301b0301e030230201600017000190001c000210002400017000180001b0001c0002100026000290002b000
010200000c114201041f1041f1040e11421104211041f1041111421104211041f104121141f10420104211040d1141f1042010421104121141f1042010421104121141f10420104111141f104201042110411114
00030000000103361034610356103661037610306102e31031310303102d31027310233102331026310283102b3102d3102d310243101d31015310123101231014310153101531016310133100f3100d3100a310
0003002005754067040675407704097540a7040d75411704177540670407754097040b7540e70412754157041b754227041175414704177541b704237542d70431754307042c7542670422754147040b75400704
0102000026014280142b0042b00427014290142d0042b00429014270142d0042b00427014270142c0042d0042a014260142c0042d0042a014280142c0042d0042a014270142c0042c0042a014290142d0042d004
011200000c0100c01010010110100c0100c010100101101011010110101301015010110101101013010150100c0100c01010010110100c0100c0101001011010180101101011010150101501013010100100e010
011200001301013010130101301013010130101301013010130101301013010130101301013010130101301013010130101301013010130101301013010130101301013010130101301013010130101301013010
__music__
01 00424344
00 00424344
00 00014344
00 13124344
00 00010244
00 13120243
00 00010343
00 12130343
00 01020343
00 12020343
00 00010443
00 12130443
00 13020443
00 13020443
00 00024443
02 01024443
02 01024343
00 52425343
00 12025343
02 00010443
02 00020443
02 00020443
00 41424344
03 41174344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
03 5a194344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 05064744

