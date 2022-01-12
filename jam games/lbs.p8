pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
--game state/loops

--permanent coroutines
curs_cor=nil
trgt_curs_cor=nil
----------------------

--globals
__t=0
current_mode=nil
---------

function _init()
 curs_cor=cocreate(draw_cursor)
	trgt_curs_cor=cocreate(anim_e_cursor)
	p_curs_cor=cocreate(anim_p_cursor)
	battle_init()
-- explore_init()	
end

function battle_init()
 -- music(0)
 trn_trckr:init()
 adv_turn()
 current_mode=modes.battle
end

function explore_init()
 music(16)
	init_col_map()
	current_mode=modes.explore
end

function win_init()
 music(32)
 current_mode=modes.win
end

function lose_init()
 music(48)
 current_mode=modes.lose
end

function _update60()
 if not input_disabled() then
  current_mode.input()
 end
 current_mode.update()
 check_for_dead()
 __t+=1
end

function _draw()
 palt(10,0)
 cls()
 current_mode.draw()
end

modes={
 --battle mode
 battle={
  input=function()
   get_ui_input()
  end,
  update=function()end,
  draw=function()
		 draw_enemies()
		 draw_flashes()
		 draw_status()
		 if not selecting_p then
		  draw_stats()
		 end
		 draw_menus()
		 if selecting_p then
		  draw_stats()
		 end
		 draw_e_cursor()
		 draw_p_cursor()
		 draw_dialogue()
		 glitch_dither()
		 screen_shake()
  end
 },
 --explore mode
 explore={
  input=function()
   if in_ui() then
    get_ui_input()
   else
    get_movement_input()
   end
  end,
  update=function()
   update_player()
  end,
  draw=function() 
   map()
   draw_player()
   draw_dialogue()
   draw_menus()
  end
 },
 --win mode
 win={
  input=function()
   get_win_input()
  end,
  update=function()end,
  draw=function()
   win_draw()
  end
 },
 --lose mode
 lose={
  input=function()
   get_lose_input()
  end,
  update=function()end,
  draw=function()
   lose_draw()
  end
 }
}

function in_ui()
 return dialogue_open()
 or menu_is_open()
end

function get_ui_input()
 if dialogue_open() then
  get_dialogue_input()
 elseif selecting_p then
  get_p_sel_input()
 elseif menu_is_open() then
  if selecting_trgt then
   get_e_sel_input()
  else
   get_menu_input()
  end
	end
end

function input_disabled()
 if current_mode==modes.win
	or	current_mode==modes.lose then
	 return false
	end
	return in_menu_anim()
	or in_dialogue_anim()				
end

function dialogue_open()
 return perm_dialogue!=nil
end

function in_dialogue_anim()
 local p=perm_dialogue
 if p then
  return not anim_fin
 end
 return false
end

function in_menu_anim()
-- return menu_cor!=nil or #cls_menu>0
 return menu_cor!=nil or cls_cor
end

function menu_is_open()
 return in_menu_anim() or #menu_stack>0
end

function win_draw()
 cls(14)
 print('u won',48,64,0)
 print('x to restart',48,80,0)
end

function lose_draw()
 cls(8)
 print('u died',48,64,0)
 print('x to restart',48,80,0)
end




-->8
--menu functions


--static params
check_sz=10
check_spd=20
menu_spd=12

--globals

cur_pos_stack={cur=1,prev=nil}
menu_stack={}
cls_all=false
menu_cor=nil
cls_cor=nil

function nxt_menu()
 return menu_stack[#menu_stack]
end

function open_menu(menu,x,y)
 sfx(1)
	local prev=cur_pos_stack.prev
 cur_pos_stack.prev={
  cur=cur_pos_stack.cur,
  prev=prev
 }
 cur_pos_stack.cur=1
 local newx, newy
 if not(x and y) then
	 local nxt_h=menu_height(menu)
	 local h_diff=nxt_menu().h-nxt_h
	 newx=nxt_menu().x+10
	 newy=nxt_menu().y+h_diff/2
	end
	local mx=x and x or newx
	local my=y and y or newy
	m={
	 x=mx,
	 y=my,
	 w=menu_width(menu),
	 h=menu_height(menu),
	 items=menu
	}
	add(menu_stack,m)
 menu_cor=cocreate(menu_anim)
end

function close_menu()
 if current_mode==modes.battle 
 and #menu_stack==1 then
  return
 end
 sfx(2)
 cls_cor=cocreate(close_anim)
end

function close_all()
 cls_all=true
 cls_all=true
 cls_cor=cocreate(close_anim)
end

function move_cur(n)
 sfx(0)
 local m=menu_stack[#menu_stack]
 local len=#m.items
 local cur_pos=cur_pos_stack.cur
 cur_pos+=n
 cur_pos=cur_pos>len and 1 or cur_pos
 cur_pos=cur_pos<1 and len or cur_pos
 cur_pos_stack.cur=cur_pos
end

function select_item()
 local menu=nxt_menu()
 local item=menu.items[cur_pos_stack.cur]
 if item.typ=='menu' then
  local menu=menus[item.sel]
 	open_menu(menu)
 end
 if item.typ=='glitch' then
  do_glitch(10)
 end
 if item.typ=='quit' then
  do_glitch(20)
  run()
 end
 if item.typ=='attack_sel' then
  selecting_trgt=true
  selected_act={
   typ='attack',
   data=nil
  }
 end
 if item.typ=='magic_sel' then
  local p=trn_trckr.crnt
  if magics[item.sel].cost>p.mp then
   battle_msg({'not enough mp!'})
  else
   selecting_trgt=true
   selected_act={
    typ='magic',
    data=magics[item.sel]
   }
  end
 end
 if item.typ=='aggro_cnfrm' then
  player_action('aggro')
 end
 if item.typ=='item_menu' then
  open_menu(get_item_menu())
 end
 if item.typ=='buff_sel' then
  local p=trn_trckr.crnt
  if buffs[item.sel].cost>p.mp then
   battle_msg({'not enough mp!'})
  else
   selected_act={
    typ='buff',
    data=buffs[item.sel]
   }
   local menu=get_plyr_menu(item.sel=='revive')
   if #menu==0 then
    battle_msg({'nobody to use it on!'})
   else
    open_menu(menu)
   end
  end
 end
 if item.typ=='item_sel' then
  selected_act={
   typ='item',
   data=items[item.sel]
  }
  if item.sel=='feather' 
  and party_all_alive() then
   battle_msg({'nobody to use it on!'})
  else
   start_p_sel(item.sel=='feather')
  end
 end
 if item.typ=='steal_sel' then
  selecting_trgt=true
  selected_act={
   typ='steal',
   data=nil
  }
 end
 -- open_menu(menus.plyr_sel)
 if item.typ=='plyr_sel' then
  player_action(selected_act.typ)  
 end
end


function draw_menus()
	for m_i=1,#menu_stack do
	 if(cls_all) break
	 if m_i==#menu_stack then
	  if (cls_cor) break
	  if menu_cor then 
	   cores_clnp(menu_cor,function()
	    menu_cor=nil
	   end)
			 if(menu_cor)break
		 end
		end
		local m=menu_stack[m_i]
	 local x2=m.x+m.w
	 local y2=m.y+m.h
	 local c1,c2=13,6
	 if m_i~=#menu_stack 
	 or selecting_p then 
	  c1=5
	  c2=5
	 end
  check_w_border(m.x,m.y,x2,y2,c1)
	 if m_i==#menu_stack 
	 and not in_menu_anim() 
	 and not dialogue_open() 
	 and not selecting_p then
	 	coresume(curs_cor)
	 end
	 for i=0,#m.items-1 do
	  local itm=m.items[i+1]
	  print(itm.txt,m.x+2,m.y+i*7+2,c2)
	 end
	end
 if cls_cor then
  cores_clnp(cls_cor,function()
   if cls_all then
	  	cur_pos_stack={cur=1,prev=nil}
   	menu_stack={}
	  else
	  	cur_pos_stack=cur_pos_stack.prev
	  	del_last(menu_stack)
	  end
	  cls_cor=nil
	  cls_all=false
	  adv_action()
  end)
 end
end

function menu_height(menu)
 return #menu*7+1
end

function menu_width(menu)
	local w=0
	for i in all(menu) do
	 if (#i.txt>w) w=#i.txt
	end
	return w*4+2
end

function menu_anim()
 local nxt=nxt_menu()
 local x_sz=nxt.w
 local y_sz=nxt.h
 local x1,y1=nxt.x,nxt.y
 for t=menu_spd,1,-1 do
 	local ti=1-(t/menu_spd)
		local x2=x1+ti*x_sz
		local y2=y1+ti*y_sz
  check_w_border(x1,y1,x2,y2,13)
  draw_fake_text(nxt,ti,x2,y2,6)
		yield()
 end
end

function close_anim()
 for t=menu_spd,0,-1 do
  local cls_menu=cls_all and menu_stack or {nxt_menu()}
	 for m in all(cls_menu) do
		 local x_sz=m.w
		 local y_sz=m.h
		 local x1,y1=m.x,m.y
	  local ti=t/menu_spd
	  local x2=x1+ti*x_sz
	  local y2=y1+ti*y_sz
   check_w_border(x1,y1,x2,y2,5)
	  draw_fake_text(m,ti,x2,y2,5)
	 end
	 yield()
	end
	for i=0,3 do yield() end
end

function draw_cursor()
 local t=0
 while true do
  local m=nxt_menu()
 	local x1=m.x+1
	 local x2=m.x+m.w-1
 	local y1=m.y+(cur_pos_stack.cur-1)*7+1
	 local y2=y1+6
  rectfill(x1,y1,x2,y2,8)
  local f=t%40
  local x=sin(f*.025)*2.5
  spr(1,x1-11+x,y1)
  t+=1
  yield()
 end
end


function draw_fake_text(m,t,xmax,ymax,c)
 for i=0,#m.items-1 do
  local txt_l=#m.items[i+1].txt
  local x1=m.x+2
  local x2=(txt_l*4-2)*t+x1
  local y1=m.y+i*7+2
  local y2=4*t+y1
  if(y1<ymax-1) then
	  x2=mid(m.x,x2,xmax-1)
	  y2=mid(m.y,y2,ymax-1)
	  rectfill(x1,y1,x2,y2,c)
	 end
 end
end

function draw_checkerboard(x1,y1,x2,y2)
 local x_cyc,y_cyc,ti,i,x,y,xx1,xx2,yy1,yy2,c,sz
 sz=check_sz
 x_cyc=ceil((x2-x1)/sz)
 y_cyc=ceil((y2-y1)/sz)
 ti=__t%check_spd/check_spd
 i=1
 for xi=-1,x_cyc do
  for yi= -1,y_cyc do
   x=(xi+ti)*sz+x1
   y=(yi+ti)*sz+y1
   if mid(x1-sz,x,x2+1)==x
   and mid(y1-sz,y,y2+1)==y then
	   c=i%2==0 and 1 or 0
	   xx1=mid(x1,x,x2)
	   xx2=mid(x1,x+sz,x2)
	   yy1=mid(y1,y,y2)
	   yy2=mid(y1,y+sz,y2)
   	rectfill(xx1,yy1,xx2,yy2,c)
   end 
   i+=1
  end
  i+=y_cyc%2+1
 end
end


-->8
--menu data

item_state={
 potion={ 
  nm='potion',
  qty=1,
  txt='potion'
 },
 elixir={
  nm='elixir',
  qty=1,
  txt='elixir'
 },
 goop={
  nm='goop',
  qty=0,
  txt='goop'
 },
 feather={
  nm='feather',
  qty=1,
  txt='feather'
 },
 special_sauce={
  nm='special_sauce',
  qty=1,
  txt='special sauce'
 }
}

item_index={'potion','elixir','goop','feather','special_sauce'}

function get_item_menu()
 local menu={}
 for indx in all(item_index) do
  local i=item_state[indx]
  if i.qty>0 then
	  obj={
	   txt=i.txt..' ('..i.qty..')',
	   typ='item_sel',
	   sel=i.nm
	  }
	  add(menu,obj)
	 end
 end
 return menu
end

function get_plyr_menu(dead)
 local m={}
 for p in all(p_index) do
  local v=stats[p]
  if v.typ=='player' and v.dead==dead then
   add(m,{txt=v.name,typ='plyr_sel'})
  end
 end
 return m
end

menus={
	brute={
		{
			txt='attack',
			typ='attack_sel'
		},
		{
		 txt='special',
		 typ='menu',
		 sel='slash'
		},
	 {
	  txt='item',
	  typ='item_menu',
	 },
	 {
	  txt='flee',
	  typ='menu',
	  sel='flee'
	 }
	},
	rogue={
		{
			txt='attack',
			typ='attack_sel'
		},
		{
		 txt='steal',
		 typ='steal_sel'
		},
	 {
	  txt='item',
	  typ='item_menu',
	 },
	 {
	  txt='flee',
	  typ='menu',
	  sel='flee'
	 }
	},
	warlock={
		{
			txt='attack',
			typ='attack_sel'
		},
		{
		 txt='spells',
		 typ='menu',
		 sel='magic'
		},
	 {
	  txt='item',
	  typ='item_menu',
	 },
	 {
	  txt='flee',
	  typ='menu',
	  sel='flee'
	 }
	},
	healer={
		{
			txt='attack',
			typ='attack_sel'
		},
		{
		 txt='healing',
		 typ='menu',
		 sel='healing'
		},
	 {
	  txt='item',
	  typ='item_menu',
	 },
	 {
	  txt='flee',
	  typ='menu',
	  sel='flee'
	 }
	},
	magic={
		{
		 txt='fire',
		 sel='fire',
		 typ='magic_sel'
		},
		{
		 txt='ice',
		 sel='ice',
		 typ='magic_sel'
		},
		{
		 txt='candy',
		 sel='candy',
		 typ='magic_sel'
		},
		{
		 txt='slime',
		 sel='slime',
		 typ='magic_sel'
		},
	},
	slash={
  {
   txt='flame slash',
   sel='flameslash',
   typ='magic_sel'
  },
  {
   txt='ice slash',
   sel='iceslash',
   typ='magic_sel'
  },
  {
   txt='aggro',
   typ='menu',
   sel='aggro_cnfrm'
  }
 },
 aggro_cnfrm={
  {
   txt='self',
   typ='aggro_cnfrm'
  }
 },
 healing={
  {
   txt='cure',
   typ='buff_sel',
   sel='cure'
  },
  {
   txt='revive',
   typ='buff_sel',
   sel='revive'
  },
 },
 flee={
  {
   txt='try again',
   typ='quit'
  }
 },
}
-->8
--input

function get_menu_input()
 if(btnp(3)) move_cur(1)
 if(btnp(2)) move_cur(-1)
 if(btnp(4)) select_item()
 if(btnp(5)) close_menu()
end

function get_movement_input()
 if(btn(0))pdx=-1
 if(btn(1))pdx=1
 if(btn(2))pdy=-1
 if(btn(3))pdy=1
 if btnp(4) then
  local x0,y0=px+4,py+4
  local x=flr(x0/8)
  local y=flr(y0/8)
  local f=fget(mget(x,y))
  	if mid(2,f,5)==f then
  		char_dialogue(f)
  	end
 end
 if btnp(5) then
  open_menu('brute',14,90)
 end
end

function get_dialogue_input()
 if btnp(4) or btnp(5) then
  adv_page()
 end
end

--function get_action_input()
-- if btnp(4) or btnp(5) then
--  adv_action()
-- end
--end

function get_e_sel_input()
 if(e_target().dead) then
  move_e_cursor(1)
 end
 if(btnp(1)) move_e_cursor(1)
 if(btnp(0)) move_e_cursor(-1)
 if(btnp(4)) e_cursor_select()
 if btnp(5) then
  selecting_trgt=false
 end
end

function get_p_sel_input()
 if(btnp(3)) move_p_cursor(1)
 if(btnp(2)) move_p_cursor(-1)
 if(btnp(4)) p_cursor_select()
 if btnp(5) then
  selecting_p=false
 end
end

--function get_p_sel_input()
-- if(p_target().dead) then
--  move_e_cursor(1)
-- end
--end

function get_win_input()
 if(btnp(4))run()
end

function get_lose_input()
 if(btnp(4))run()
end
-->8
--dialogue

--globals
txt_anims={}
perm_dialogue=nil
anim_fin=false


--static params
c_dial={
 x=32,
 y=100,
 w=88,
 h=24
} 
  
c_d_prms={
 spd=2,
 x0=3,
 y0=6,
 dist=5,
 len=8,
 e_len=0,
 crv=3,
 rev=false,
 clr=6
}

b_dial={
	x=6,
	y=80,
	w=121,
	h=16
}

b_d_prms={
 spd=1,
 x0=3,
 y0=6,
 dist=5,
 len=10,
 e_len=0,
 crv=6,
 rev=false,
 clr=7
}

e_dial={
	x=6,
	y=0,
	w=121,
	h=16
}

e_d_prms={
 spd=1,
 x0=3,
 y0=6,
 dist=5,
 len=10,
 e_len=0,
 crv=6,
 rev=false,
 clr=6
}

t_d_prms={
 spd=2,
 x0=3,
 y0=6,
 dist=5,
 len=10,
 e_len=40,
 crv=6,
 rev=true,
 clr=7
}
--------------

function adv_page()
 anim_fin=false
 local p=perm_dialogue
 if p.pg==p.len then
  close_dialogue()
 else
  p.pg+=1
  p.anim.cor=cocreate(anim_text)
  coresume(p.anim.cor,p.anim.prms,p.pg,true)
 end
end

function char_dialogue(n)
 local d=char_dialogues[n]
 port=portraits[portraits_ref[n]]
	create_dialogue(d,c_d_prms,c_dial,port)
end

function battle_msg(d)
 create_dialogue(d,b_d_prms,b_dial)
end

function enemy_msg(d)
 create_dialogue(d,e_d_prms,e_dial)
end

function throw_txt(txt,x,y,clr)
 local prms=t_d_prms
 if(clr)prms.clr=clr
	local anim=txt_obj(txt,prms,x,y)
 coresume(anim.cor,anim.prms)
 add(txt_anims,anim.cor)
end

function create_dialogue(txt,txt_p,bx_p,port)
	anim_fin=false
	local anim=txt_obj(txt,txt_p,bx_p.x,bx_p.y)
	coresume(anim.cor,anim.prms,1,true)
	perm_dialogue={
		x0=bx_p.x,
		y0=bx_p.y,
		w=bx_p.w,
		h=bx_p.h,
		anim=anim,
		pg=1,
		len=#txt
	}
	if(port)perm_dialogue.port=port
end


function draw_dialogue()
	for a in all(txt_anims) do
	 cores_clnp(a, function()
	  del(txt_anims,a)
	 end)
	end
 local p=perm_dialogue
 if (p==nil) return
 local x1,y1=p.x0,p.y0
 local x2,y2=x1+p.w,y1+p.h
 check_w_border(x1,y1,x2,y2,5)
 if p.port then
  check_w_border(5,100,29,124,5)
  spr(p.port,6,101,3,3)
 end
 coresume(p.anim.cor)
 if(not anim_fin)sfx(3)
end

function close_dialogue()
 perm_dialogue=nil
 portrait=nil
 adv_action()
end


function txt_obj(txt,p,x0,y0)
 local cor=cocreate(anim_text)
 local prms={
 	txt=txt,
 	spd=p.spd,
  x0=x0+p.x0,
  y0=y0+p.y0,
  dist=p.dist,
  len=p.len,
  e_len=p.e_len,
  crv=p.crv,
  rev=p.rev,
  clr=p.clr
 }
 return {cor=cor,prms=prms}
end


function anim_text(txt,t)
 yield()
 local txt=pg and p.txt[pg] or p.txt
 local max_t=p.spd*(#txt+p.len+p.e_len)
 local t=max_t
 while t>0 or perm do
  local fct=1-t/max_t
  local lim=flr(fct*max_t/p.spd)
	 local ln=0
	 local col=0
	 for i=1,lim do
	  local char=sub(txt,i,i)
	  if char=='$' then
	   ln+=1
	   col=0
	  else
		  local drft=1-(lim-i)/p.len
		  local dy=max(0,drft*p.dist)
		  if(dy>0)dy+=-sgn(p.rev)*(sin(drft)+.5)*p.crv
		  local x=col*4+p.x0
		  local y=ln*8+p.y0
		  print(char,x,y+dy,p.clr)
		  col+=1
		 end
	 end
	 t=t>=0 and t-1 or t
	end
end

char_dialogues={
 [2]={
 	"sup. nice textboxes u $got there."
 },
 [3]={
  "hoo boy. lookit them $characters.",
  "continued"
 }
}

portraits_ref={
	[2]='rogue',
	[3]='healer'
}

portraits={
 rogue=16,
 healer=19
}

-->8
--player

px=64
py=64
pdx=0
pdy=0
p_t=1
p_anim_spd=10
p_spr=2
p_spd=.6
x_col_buf=6
y_col_buf=7

colmap={}

function update_player()
 local s=p_spd
	if abs(pdx)+abs(pdy)==2 then
	 s*=.707
	end
	if pdx!=0 or pdy!=0 then
	 p_t+=1
	 if(p_t%p_anim_spd==0)p_spr+=1
	 if(p_spr>5)p_spr=2
	end
	local nxtx=flr(px+pdx)
	local nxty=flr(py+pdy)
	if not check_col(nxtx,nxty) then
		px+=pdx*s
		py+=pdy*s
 end
 pdx=0
 pdy=0
end

function draw_player()
 spr(p_spr,px,py)
end


function init_col_map()
 for xi=0,16 do
  for yi=0,16 do
   local f=fget(mget(xi,yi))
   if f==1 then
    add(colmap,{
    	x=xi*8,
    	y=yi*8
    })
   end
  end
 end
end

function check_col(x,y)
 for c in all(colmap) do
  if mid(c.x-x_col_buf,x,c.x+x_col_buf)==x
  and mid(c.y-y_col_buf,y,c.y+y_col_buf)==y then
   return true
  end
 end
 return false
end


-->8
--battle

cur_act=nil

selecting_trgt=false
selecting_p=false
e_sel=1
p_sel=1

brute_aggro=false

battle_port=false

selected_act={
 typ=nil,
 data=nil
}

e_index={
 'iceboi',
 'fireboi',
 'bigboss',
 'candyboi',
 'slimeboi'
}
 
e_pos_index={
 {x=12,y=36},
 {x=28,y=18},
 {x=59,y=8},
 {x=90,y=18},
 {x=106,y=36},
}

p_index={
 'brute',
 'warlock',
 'healer',
 'rogue'
}


function e_target()
 return stats[e_index[e_sel]]
end

function p_target()
 return stats[p_index[p_sel]]
end

function e_pos()
 return e_pos_index[e_sel]
end

function start_p_sel(dead)
 selecting_dead=dead
 selecting_p=true
 p_sel=1
 while(p_target().dead~=selecting_dead) do
  p_sel+=1
 end
end

--function p_target(dead)
-- local p_i=0
-- local plyr=nil
-- for i=1,cur_pos_stack.cur do 
--  p_i+=1
--  plyr=stats[p_index[p_i]]
--  while plyr.dead~=dead do
--   p_i+=1
--   plyr=stats[p_index[p_i]]
--  end
-- end 
-- return p_i
--end

function adv_action()
	if cur_act then
	 cores_clnp(cur_act, function()
	  cur_act=nil
	  adv_turn()
	 end)
 end
end

function adv_turn()
 trn_trckr:get_nxt()
 local trn=trn_trckr.crnt
 if trn_trckr:plyr_trn() then
  open_menu(menus[trn.name],10,90)
 else
  enemy_action(trn.name)
 end
end

function move_p_cursor(n)
 p_sel+=n
 p_sel=p_sel>4 and 1 or p_sel
 p_sel=p_sel<1 and 4 or p_sel
 while p_target().dead~=selecting_dead do
  p_sel+=n
  p_sel=p_sel>4 and 1 or p_sel
  p_sel=p_sel<1 and 4 or p_sel
 end
end

function move_e_cursor(n)
 e_sel+=n
 e_sel=e_sel>5 and 1 or e_sel
 e_sel=e_sel<1 and 5 or e_sel
 while(e_target().dead) do
  e_sel+=n
  e_sel=e_sel>5 and 1 or e_sel
  e_sel=e_sel<1 and 5 or e_sel
 end
end

function e_cursor_select()
 selecting_trgt=false
	player_action(selected_act.typ)
end

function p_cursor_select()
 player_action(selected_act.typ)
end

function player_action(nm)
 if nm=='attack' then
  cur_act=cocreate(do_attack)
 end
 if nm=='magic' then
  cur_act=cocreate(do_magic)
 end
 if nm=='buff' then
  cur_act=cocreate(do_buff)
 end
 if nm=='item' then
  cur_act=cocreate(do_item) 
 end
 if nm=='steal' then
  cur_act=cocreate(do_steal)
 end
 if nm=='aggro' then
  cur_act=cocreate(do_aggro)
 end
 if(cur_act)coresume(cur_act)
end

function enemy_action(nm)
 if nm=='ice boi'
 or nm=='fire boi'
 or nm=='slime boi'
 or nm=='candy boi' then
  cur_act=cocreate(do_boi)
 end
 if nm=='big boss' then
  cur_act=cocreate(do_boss)
 end
 if(cur_act)coresume(cur_act)
end

function do_attack()
 close_all()
 yield()
 battle_port=true
 local trn=trn_trckr.crnt
 local name=trn.name
 local target=e_target()
 local d1={name..' slashes at '..target.name..'!'}
 battle_msg(d1)
 yield()
 sfx(4)
 local dmg=trn.str
 local x=e_pos().x
 local y=e_pos().y
 throw_txt(tostr(dmg),x-1,y-2)
 target.hp-=dmg
 local d2={target.name..' takes '..dmg..' dmg!'}
 battle_msg(d2)
 yield()
 battle_port=false
end

function do_magic()
 local name=trn_trckr.crnt.name
 local sel_mgc=selected_act.data
 local target=e_target()
 local res=check_resist(sel_mgc.dmg,sel_mgc.typ,target)
 local d1={sel_mgc.name..' strikes '..target.name..'!'}
 local d2={res.msg}
 close_all()
 yield()
 battle_port=true
 make_flashes(sel_mgc.clr,10)
 battle_msg(d1)
 sfx(5)
 trn_trckr.crnt.mp-=sel_mgc.cost
 yield()
 battle_msg(d2)
 yield()
 if res.dmg>0 then
  sfx(4)
	 local x=e_pos().x
	 local y=e_pos().y
	 throw_txt(tostr(res.dmg),x-2,y-2)
	 target.hp-=res.dmg
	 local d3={target.name..' takes '..res.dmg..' dmg!'}
	 battle_msg(d3)
	 yield()
	end
 battle_port=false
end

function do_buff()
 local p=trn_trckr.crnt
 local buff=selected_act.data
 local p_sel=p_target(buff.name=='revive')
 local trgt=stats[p_index[p_sel]]
 local d1={p.name..' used '..buff.name..' on '..trgt.name}
 local d2={trgt.name..buff.msg}
 close_all()
 yield()
 battle_port=true
 enemy_msg(d1)
 yield()
 buff.func(trgt)
 p.mp-=buff.cost
 for s in all(buff.stats) do
  make_stat_flashes(s,p_sel-1,30)
 end
 enemy_msg(d2)
 yield()
 battle_port=false
end

function do_item()
 local p=trn_trckr.crnt
 local item_data=selected_act.data
 local p_sel=p_target(item_data.name=='feather')
 local trgt=p_target()
 local d1={p.name..' used '..item_data.name..' on '..trgt.name}

 local d2={trgt.name.. item_data.msg}

 close_all()
 yield()
 battle_port=true
 enemy_msg(d1)
-- selecting_p=false
 yield()

 item_data.func(trgt)
 item_state[item_data.key].qty-=1
 for s in all(item_data.stats) do
  make_stat_flashes(s,p_sel-1,30)
 end
 enemy_msg(d2)
 yield()
 battle_port=false
end

function do_steal()
 local p=trn_trckr.crnt
 local trgt=e_target()
 local item=trgt.item
 local d1={p.name..' mugged '..trgt.name}
 local d2={'received '..item..'!'}
 close_all()
 yield()
 battle_port=true
 battle_msg(d1)
 yield()
 battle_msg(d2)
 item_state[item].qty+=1
 yield()
 battle_port=false
end

function do_aggro()
 brute_aggro=true
 local d1={'brute used aggro', 'all enemies glare at brute'}
 close_all()
 yield()
 battle_port=true
 battle_msg(d1)
 yield()
 battle_port=false
end

function do_boi()
 battle_port=true
 local p=trn_trckr.crnt
 local trgt=get_random_target()
 if(brute_aggro)trgt=stats['brute']
 local d1={p.name..' '..p.verb..' '..trgt.name}
 enemy_msg(d1)
 yield()
 local dmg=5
 throw_txt(tostr(dmg),60,70)
 sfx(11)
 trgt.hp-=dmg
 if(trgt.hp<0)trgt.hp=0
 make_stat_flashes('name',trgt.row-1,60)
 local d2={trgt.name..' takes '..dmg..' damage!'}
 enemy_msg(d2)
 yield()
 battle_port=false
end

function do_boss()
 battle_port=true
 local p=trn_trckr.crnt
 local d1={p.name..' slams the party!'}
 enemy_msg(d1)
 yield()
 local dmg=10
 throw_txt(tostr(dmg),25,70)
 throw_txt(tostr(dmg),40,70)
 throw_txt(tostr(dmg),55,70)
 throw_txt(tostr(dmg),70,70)
 make_flashes(8,10)
 for i=1,4 do
  local plyr=stats[p_index[i]]
  plyr.hp-=dmg
  if(plyr.hp<0)plyr.hp=0
 end
 sfx(11)
 local d2={'everyone takes '..dmg..' damage!'}
 enemy_msg(d2)
 yield()
 battle_port=false
end

function draw_e_cursor()
 if selecting_trgt then
  coresume(trgt_curs_cor)
 end
end

function draw_p_cursor()
	if selecting_p and cls_cor==nil then
	 coresume(p_curs_cor)
	end
end

function anim_p_cursor()
 local t=0
 while true do
--  draw_stats()
  local x=37
  local y=91+(p_sel-1)*7
  local f=t%40
  -- dude, gotta optimise this
  -- by creating a reusable
  -- sin*t offset coroutine
  local dx=sin(f*.025)*2.5
  spr(1,x+dx,y)
  t+=1
  yield()
 end
end


function anim_e_cursor()
 local t=0
 while true do
  local pos=e_pos()
  local x,y=pos.x,pos.y
  local f=t%40
  local dy=sin(f*.025)*2.5
  spr(11,x,y+dy)
  t+=1
  yield()
 end
end




-->8
--stats


trn_trckr={
 cntr=1,
 tkrs={},
 crnt=nil,
 init=function(self)
  for nm,v in pairs(stats) do
   local obj={
    name=v.name,
    spd=v.spd,
    nxt=v.spd
   }
   self.tkrs[nm]=obj
   -- add(self.tkrs,obj)
  end
 end,
 get_nxt=function(self)
  local nxt=nil
  while nxt==nil do
   for nm,t in pairs(self.tkrs) do
    if t.nxt<=self.cntr 
    and not stats[nm].dead then
     nxt=nm
     t.nxt=t.nxt+t.spd
     break
    end
   end
   if (nxt==nil)self.cntr+=1
  end
   self.crnt=stats[nxt]
 end,
 plyr_trn=function(self)
  return self.crnt.typ=='player'
 end
}


function check_resist(dmg,typ,e)
	for i in all(e.imm) do
	 if i==typ then 
	  return {
	   msg="it has little effect!",
	   dmg=dmg/2
	  }
	 end
	end
	for r in all(e.res) do
	 if r==typ then
	  return {
	   msg="it's somewhat effective!",
	   dmg=dmg
	  }
	 end
	end
	for w in all(e.weak) do
	 if (w==typ) then
	 	return {
	 	 msg="it's super effective!",
	 	 dmg=dmg*2
	 	}
	 end
	end
end

function get_high_hp()
 local hihp=0
 local plyr=nil
 for _,s in pairs(stats) do
  if s.typ=="player" 
  and not s.dead then
   if s.hp>hihp then
    hihp=s.hp
    plyr=s
   end
  end
 end
 return plyr
end

function get_random_target()
 local r=flr(rnd(4))+1
 local plyr=stats[p_index[r]]
 while plyr.dead do
  r=flr(rnd(4))+1
  plyr=stats[p_index[r]]
 end
 return plyr
end

function check_for_dead()
 for _,v in pairs(stats) do
  if (v.hp<=0) v.dead=true
  if v.name=='brute' and v.dead then
   brute_aggro=false
  end
 end
 if party_dead() then
 	lose_init()
 end
 if enemies_dead() then
  win_init()
 end
end

function enemies_dead()
 for e in all(e_index) do
  if (not stats[e].dead) return false
 end
 return true
end

function party_dead()
 for p in all(p_index) do
  if (not stats[p].dead) return false
 end
 return true
end

function party_all_alive()
 for p in all(p_index) do
  if (stats[p].dead) return false
 end
 return true
end

function revive_player(p)
 p.dead=false 
 p.hp=1 
 p.mp=1
 local nxt=trn_trckr.cntr+p.spd
 trn_trckr.tkrs[p.name].nxt=nxt
end

stats={
	brute={
		name="brute",
		typ="player",
  port=16,
		row=1,
		spd=6,
		hp=25,
		mxhp=25,
		mp=25,
		mxmp=25,
		str=12,
		sts={},
		lim=0,
		mxlim=10,
  saucy=false,
		dead=false
	},
	warlock={
	 name="warlock",
	 typ="player",
  port=16,
		row=2,
		spd=10,
	 hp=15,
		mxhp=15,
		mp=20,
		mxmp=20,
		str=4,
		sts={},
  saucy=false,
		dead=false
	},
	healer={
	 name="healer",
	 typ="player",
  port=16,
		row=3,
		spd=9,
		hp=15,
		mxhp=15,
		mp=40,
		mxmp=40,
		str=4,
		sts={},
  saucy=false,
		dead=false
	},
	rogue={
	 name="rogue",
	 typ="player",
  port=16,
		row=4,
		spd=5,
	 hp=20,
		mxhp=20,
		mp=0,
		mxmp=0,
		str=10,
		sts={},
  saucy=false,
		dead=false
	},
	bigboss={
	 name="big boss",
	 typ="enemy",
	 port=100,
	 spd=12,
	 hp=40,
	 mxhp=40,
	 res={},
	 imm={"ice","candy","slime","fire"},
	 weak={},
	 sts={},
  item='goop',
		dead=false
	},
	iceboi={
	 name="ice boi",
	 verb="chills",
	 typ="enemy",
	 port=102,
	 spd=8,
	 hp=20,
	 mxhp=20,
	 res={"candy", "slime"},
	 imm={"ice"},
	 weak={"fire"},
	 sts={},
  item='potion',
		dead=false
	},
	fireboi={
	 name="fire boi",
	 verb="roasts",
	 typ="enemy",
	 port=104,
	 spd=8,
		hp=20,
	 mxhp=20,
	 res={"candy", "slime"},
	 imm={"fire"},
	 weak={"ice"},
	 sts={},
  item='elixir',
		dead=false
	},
	candyboi={
	 name="candy boi",
	 verb="chomps",
	 typ="enemy",
	 port=106,
	 spd=8,
		hp=20,
	 mxhp=20,
	 res={"fire", "ice"},
	 imm={"candy"},
	 weak={"slime"},
	 sts={},
  item='feather',
		dead=false
	},
	slimeboi={
	 name="slime boi",
	 verb="swamps",
	 typ="enemy",
	 port=108,
	 spd=8,
		hp=20,
	 mxhp=20,
	 res={"fire", "ice"},
	 imm={"slime"},
	 weak={"candy"},
	 sts={},
  item='special_sauce',
		dead=false
	}
}

buffs={
 cure={
  name='cure',
  clr=7,
  msg=' regained 10 hp!',
  stats={'hp'},
  cost=10,
  func=function(x)
   x.hp+=10
   x.hp=min(x.mxhp,x.hp)
  end
 },
 revive={
  name='revive',
  clr=11,
  msg=' was revived!',
  stats={'name','hp','mp'},
  cost=20,
  func=function(x)
   revive_player(x)
  end
 }
}
magics={
 fire={
  name="fire",
  typ="fire",
  clr=9,
  dmg=8,
  cost=10
 },
 ice={
  name="ice",
  typ="ice",
  clr=12,
  dmg=8,
  cost=10
 },
 candy={
  name="candy",
  typ="candy",
  clr=14,
  dmg=8,
  cost=10
 },
 slime={
  name="slime",
  typ="slime",
  clr=11,
  dmg=8,
  cost=10
 },
 flameslash={
  name="flame",
  typ="fire",
  clr=9,
  dmg=7,
  cost=10
 },
 iceslash={
  name="sharp ice",
  typ="ice",
  clr=12,
  dmg=6,
  cost=10
 }
}

items={
 potion={
  name="potion",
  key='potion',
  msg=" regained 20 hp!",
  stats={'hp'},
  func=function(x) 
   x.hp+=20 
   x.hp=min(x.hp,x.mxhp)
  end
 },
 elixir={
  name="elixir",
  key='elixir',
  msg=" regained all hp/mp!",
  stats={'hp','mp'},
  func=function(x) 
   x.hp=x.mxhp 
   x.mp=x.mxmp 
  end
 },
 goop={
  name="goop",
  key='goop',
  msg=" ...got gooped!",
  stats={'mp'},
  func=function(x) 
   x.mp+=20 
   x.mp=min(x.mp,x.mxmp)
  end
 },
 feather={
  name="feather",
  key="feather",
  msg=" was revived",
  stats={'name','hp','mp'},
  func=function(x) 
   revive_player(x)
  end
 },
 special_sauce={
  name="special sauce",
  key="special_sauce",
  msg=" became saucy!",
  stats={'name'},
  func=function(x) x.saucy=true end
 }
}
-->8
--draw battle stuff

function check_w_border(x1,y1,x2,y2,c)
 draw_checkerboard(x1,y1,x2,y2)
 rect(x1,y1,x2,y2,c)
end

function draw_status()
 local turn_p=trn_trckr.crnt
 if trn_trckr:plyr_trn() then
  check_w_border(10,77,72,87,14)
	 local name=turn_p.name
	 print(name.."'s turn",12,80,14)
	 if selecting_trgt then
	  local e_name=stats[e_index[e_sel]].name
	  local xoff=#e_name*2
	  check_w_border((64-xoff)-4,0,64+xoff+2,8,13)
	  print(e_name,64-xoff,2,7)
	 end
 end
 if battle_port then
  check_w_border(10,90,36,119,8)
	 local nme=turn_p.name
	 local sprt=turn_p.port
	 spr(sprt,16,98,2,2)
 end
end

function draw_stats()
 check_w_border(47,90,127,119,13)
 check_w_border(83,82,101,90,13)
 print('hp',89,84,9)
 check_w_border(107,82,125,90,13)
 print('mp',113,84,12)
 for i=1,#p_index do
  local p=stats[p_index[i]]
  local y=92+(i-1)*7
  if p==turn_p then
   rectfill(48,y-1,80,y+5,14)
  end
  if p.dead then
   rectfill(48,y-1,80,y+5,8)
  end
  if selecting_p and cls_cor==nil then
   local by=90+(p_sel-1)*7
   rect(47,by,80,by+8,6)
  end
  draw_stat_flashes()
  print(p.name,49,y,7)
  print(p.hp..'/'..p.mxhp,83,y,9)
  print(p.mp..'/'..p.mxmp,107,y,12)
 end
end

function draw_enemies()
 if not stats.bigboss.dead then
  spr(64,48,20,4,4)
 end
 if not stats.iceboi.dead then
  spr(102,8,48,2,2)
 end
 if not stats.fireboi.dead then
  spr(104,24,30,2,2)
 end
 if not stats.candyboi.dead then
  spr(106,86,30,2,2)
 end
 if not stats.slimeboi.dead then
  spr(108,102,48,2,2)
 end
end


-->8
--fx

flash_t=-1
flash_clr=8

name_flash_t=-1
name_flash_row=nil
name_flash_clr=8

hp_flash_t=-1
hp_flash_row=nil
hp_flash_clr=9

mp_flash_t=-1
mp_flash_row=nil
mp_flash_clr=12

glitch_t=-1

function make_flashes(clr,len)
 flash_t=__t+len
 flash_clr=clr
end

function draw_flashes()
 if flash_t>=__t then
  if __t%4==0 then
   cls(flash_clr)
  end
 end
end

function make_stat_flashes(field, row, len)
 if field=='name' then
  name_flash_t=__t+len
  name_flash_row=row
 end
 if field=='hp' then
  hp_flash_t=__t+len
  hp_flash_row=row
 end
 if field=='mp' then
  mp_flash_t=__t+len
  mp_flash_row=row
 end
end

-- function make_name_flashes(row,len)
--  name_flash_t=__t+len
--  name_flash_row=row
-- end

-- function make_hp_flashes(row,len)
--  hp_flash_t=__t+len
--  hp_flash_row=row
-- end

-- function make_mp_flashes(row,len)
--  mp_flash_t=__t+len
--  mp_flash_row=row
-- end

function draw_stat_flashes()
 if name_flash_t>=__t then
  draw_flash_block(48,name_flash_row,32,name_flash_clr)
 end
 if hp_flash_t>=__t then
  draw_flash_block(82,hp_flash_row,20,hp_flash_clr)
  -- rectfill(48,y,80,y+4,hp_flash_clr)
 end
 if mp_flash_t>=__t then
  draw_flash_block(106,mp_flash_row,20,mp_flash_clr)
 end
end

function draw_flash_block(x,row,w,clr)
 if __t%6<3 then
  local y=91+row*7
  rectfill(x,y,x+w,y+6,clr)
 end
end

function glitch_dither()
 if glitch_t>=__t then
		for i=1,600 do
		 local x=flr(rnd(127))
		 local y=flr(rnd(127))
		 local c=flr(rnd(15))+1
		 pset(x,y,c)
		end

	end

end

function do_glitch(len)
 sfx(10)
 glitch_t=__t+len
 shake+=.25
end


shake=0
function screen_shake()
 local x=16-rnd(32)
 local y=16-rnd(32)
 x*=shake
 y*=shake
 camera(x,y)
 if shake>0 then
  print('error',56+rnd(10)-5,64+rnd(10)-5,8)
 end
 shake=shake*.95
 if (shake<0.05) shake=0
end
-->8
--util

function del_last(i)
 del(i,i[#i])
end

dbg_msgs={}

function dbg_print(str)
 add(dbg_msgs,str)
end

function draw_dbg()
 for i=1,#dbg_msgs do
  print(dbg_msgs[i],6,6*i,7)
 end
 dbg_msgs={}
end

function draw_fps()
 print((stat(1)*100)..'%',0,0,7)
end

function cores_clnp(cor,f)
 coresume(cor)
 if costatus(cor)=='dead' then
  f()
 end
end



__gfx__
000000000001110000044000000440000004400000044000000dd0000008800022222222aaaaaaaaaaaaaaaa0018810000000000000000000000000000000000
000000000001811000444400004444000044440000444400000dd0000008800022222222aaaaaaaaa00000aa0018810000000000000000000000000000000000
0070070011118811000220000002200000022000000220000000d0000000800022222222aa0000aaaaaa00aa0018810000000000000000000000000000000000
00077000188888810000200000002000000020000000200000ddddd00088888022222222aa0aa0aaaaa00aaa0018810000000000000000000000000000000000
0007700011118811002222200022222000222220002222200000d0000000800022222222aaaaa0aaaaaa000a1818818100000000000000000000000000000000
0070070000018110000020200000200000202000000020000000d0000000800022222222aaa00aaaaaaaa00a0188881000000000000000000000000000000000
000000000001110000022200000222000002220000022200000ddd000008880022222222aa00000aaaa000aa0018810000000000000000000000000000000000
000000000000000000020020000202000020020000020200000d0d000008080022222222aaaaaaaaa000aaaa0001100000000000000000000000000000000000
00000000000000000000000a00022222222222222220000a00000000111111100000000a00000000000000000000000000000000000000000000000000000000
00000000000000000000000a00228888888888888820000a00000011222222211000000a00000000000000000000000000000000000000000000000000000000
00002222222222222220000a02228888888888888822220a00000122222222222100000a00000000000000000000000000000000000000000000000000000000
00002ddddddddddddd22220a02288888888888888888820a00001222222222222210000a00000000000000000000000000000000000000000000000000000000
00022dddddddddddddddd20a02288888888888888888820a00012222222222222221000a00000000000000000000000000000000000000000000000000000000
0222ddddddddddddddddd22a02288888888881888888820a00122222222222225222100a00000000000000000000000000000000000000000000000000000000
022ddddddddddd1ddddddd2a02888818888881888888820a00122255222222255222100a00000000000000000000000000000000000000000000000000000000
022ddd111ddddd11dddddd2a02888818888811888888820a01222225522222552222210a00000000000000000000000000000000000000000000000000000000
022ddd111ddddd11dddddd2a02881118888811188888820a01222222552225522222210a00000000000000000000000000000000000000000000000000000000
022ddddddddddd11dddddd2a02888188888811188888820a01222222222222222222210a00000000000000000000000000000000000000000000000000000000
022ddddddddddddddddddd2a02888888888888888881820a01222222222222222222210a00000000000000000000000000000000000000000000000000000000
022ddddddddddddddddddd2a02888888888888888811220a01222252222222225222210a00000000000000000000000000000000000000000000000000000000
022ddddddddddddddd11dd2a02881888888888888118220a01222222222222222222210a00000000000000000000000000000000000000000000000000000000
022dddddddd11111111ddd2a02881888888888888188220a01222222222222222222210a00000000000000000000000000000000000000000000000000000000
0022ddddd111dddddddddd2a02281888888888811888220a01222222222222222222210a00000000000000000000000000000000000000000000000000000000
0022ddd111ddddddddddd22a02281888888888118888200a00122222222222222222100a00000000000000000000000000000000000000000000000000000000
0002dd11ddddddddddddd20a02281888888881188888200a00122225555555555522100a00000000000000000000000000000000000000000000000000000000
0002d11dddddddddddddd20a02221118888111888882200a00012252222222222221000a00000000000000000000000000000000000000000000000000000000
0002ddddddddddddddddd20a02288811111188888222000a00001222222222222210000a00000000000000000000000000000000000000000000000000000000
00022dddddddddddddd2220a00228888888888882200000a00000122222222222100000a00000000000000000000000000000000000000000000000000000000
000022dddddddddddd22000a00022222222222222000000a00000011222222211000000a00000000000000000000000000000000000000000000000000000000
000002222dddd2222220000a00000002222222200000000a00000000111111100000000a00000000000000000000000000000000000000000000000000000000
00000022222222000000000a00000000000000000000000a00000000000000000000000a00000000000000000000000000000000000000000000000000000000
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa00000000000000000000000000000000000000000000000000000000
0000000000eeeeeeeeee0000000000000000000000000000000609999990000000000eeeeee0000000000bbbbbb0000000000000000000000000000000000000
00000000eee88888888ee0000000000000000000000000000006669999999000000eeeeeeeeee000000bbbbbbbbbb00006660000000000000000000000000000
0000000ee88888888888eee0000000000000000000000000009996669999990000eeeeeeeeeeee0000bbbbbb00bbb66660000000000000000000000000000000
00000eee88888888888888ee00000000000000000000000009999999666699900eeeee00000eeee00bbb000b00666bb000000000000000000000000000000000
00000e888888888888888888ee000000000000000000000009999000000966660eeeee000000eee00bbb006666bbbbb000000000000000000000000000000000
00000e8888888888888888888ee0000000000000000000009999900000099999666eeeeee000eeeebbbb66bb00bbbbbb00000000000000000000000000000000
0000ee88888888888888888888e0000000000000000000009999900990099999eee66ee00000eee6666600bb00bbbbbb00000000000000000000000000000000
000ee800008888888800000888ee000000000000000000009999999900099999eeeee6666666666ebbbb00000000bbbb00000000000000000000000000000000
000e88888008888800088808888e000000000000000000609999999000099999eeeeeee066666eeebbbb00000000bbbb00000000000000000000000000000000
00ee88888880888808888888888e000000000000000000669999990000000099eeeeee66ee0006666bbbbbbb00bbbbbb00000000000000000000000000000000
00e888888880888808888888888e000000000000000000066999900000000099ee6666eeee000eeeb6666bbb00bbbbbb00000000000000000000000000000000
00e888880080008080008888888ee0000000000000000000666666660999966666eeeeee00000ee00bbbb6666666666000000000000000000000000000000000
00e8888800088888000088888888e000000000000000000009999996666669900eeeeee00000eee00bbbbbbbb00bbb6666600000000000000000000000000000
00e8888800088888000088888888e0000000000000000000009999999999990000eeeee00eeeee0000bbbbbbb00bbb0000066666600000000000000000000000
00e888888008888800008888888ee00000000000000000000009999999999000000eeeeeeeeee000000bbbbbbbbbb00000000000066666600000000000000000
00e888888888888880088888888ee0000000000000000000000009999990000000000eeeeee0000000000bbbbbb0000000000000000000000000000000000000
00e888888888888888888888888ee000000002222220000000000111111000000000044944400000000022222222000000000333333300000000000000000000
00e888888888000000000088888ee0000002228888222000000111cccc111000000444999944400000222eeeeeee2200003333bbbbb330000000000000000000
00e888888000888888888008888ee000002218888818220000111cccccc111000444499999994400022eeeeeeeeee220033bbbbbbbbb33000000000000000000
00e888880088888888888800888ee0000228111881188220011ccccccc1cc110049999999999944022ee111eee111e2033bb1bbbbb1bb3300000000000000000
00e8888008888888888888808888e000228888188188882001cccc11cc11cc1144111199111199402eee1e11ee1e1e203bbbbbbbbbbbbb330000000000000000
00e888808888888888888880888ee000288188888818882211cc111cccc1111149999999999999942eeeeeeeeeeeee223bbbbbbbbbbbbbb30000000000000000
00ee88808888888888888880088e000028888888888888821cc11cccccccc1c149999999999999942eeeeeeeeeeeeee23bbbbbbbbbbbbbb30000000000000000
000e8888888888888888888088ee000028888888888888821cccccc1ccccccc149991999991999942eee11ee1eee1ee23bbbbbbbbbbbbbb30000000000000000
000eee8888888888888888888ee0000028888888888888821ccccccccc1cccc149999999999999942eee11ee11e11ee23b11111111111bb30000000000000000
00000ee88888888888888888eee0000028888888888888221cccccccccccccc149999991999999442ee11111e111e1e23b11bbbbbbbb1bb30000000000000000
000000ee88888888888888eeee00000022881111118882221ccc111c1ccc1c11499999111199994422e1ee11e11ee1e233b11bbbbbb11b330000000000000000
0000000eee888888888eeeeee0000000028818888118222011cc1c1111111110449991999199944402eeeeeeeeeeee2203bb11bb1111b3330000000000000000
000000000eeeeee88eeeeee0000000000228888888122220011cccccccc111100499919911994444022eeeeeeeee2220033bbb111bbb33300000000000000000
0000000000eeeeeeeeee000000000000002288888822222000111ccccc1111000444991119944440002eeeeeee2222200033bbbbbb3333000000000000000000
00000000000000eee00000000000000000022222222220000001111c11111000000449999444400000022eee2222220000033bbb333330000000000000000000
00000000000000000000000000000000000022222222000000001111111000000000444444440000000022222220000000003333333300000000000000000000
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
0000000000000000000000000000000000000000000000000000000000eeeeeeeeee000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000eee88888888ee00000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000ee88888888888eee000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000eee88888888888888ee00000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000e888888888888888888ee000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000e8888888888888888888ee00000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000ee88888888888888888888e00000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000ee800008888888800000888ee0000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000e88888008888800088808888e0000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000ee88888880888808888888888e0000000000000000000000000000000000000000000000000000
00000000000000000000000000000449444000000000000000e888888880888808888888888e0000000000000022222222000000000000000000000000000000
00000000000000000000000000044499994440000000000000e888880080008080008888888ee00000000000222eeeeeee220000000000000000000000000000
00000000000000000000000004444999999944000000000000e8888800088888000088888888e000000000022eeeeeeeeee22000000000000000000000000000
00000000000000000000000004999999999994400000000000e8888800088888000088888888e00000000022ee111eee111e2000000000000000000000000000
00000000000000000000000044111199111199400000000000e888888008888800008888888ee0000000002eee1e11ee1e1e2000000000000000000000000000
00000000000000000000000049999999999999940000000000e888888888888880088888888ee0000000002eeeeeeeeeeeee2200000000000000000000000000
00000000000000000000000049999999999999940000000000e888888888888888888888888ee0000000002eeeeeeeeeeeeee200000000000000000000000000
00000000000000000000000049991999991999940000000000e888888888000000000088888ee0000000002eee11ee1eee1ee200000000000000000000000000
00000000000000000000000049999999999999940000000000e888888000888888888008888ee0000000002eee11ee11e11ee200000000000000000000000000
00000000000000000000000049999991999999440000000000e888880088888888888800888ee0000000002ee11111e111e1e200000000000000000000000000
00000000000000000000000049999911119999440000000000e8888008888888888888808888e00000000022e1ee11e11ee1e200000000000000000000000000
00000000000000000000000044999199919994440000000000e888808888888888888880888ee00000000002eeeeeeeeeeee2200000000000000000000000000
00000000000000000000000004999199119944440000000000ee88808888888888888880088e0000000000022eeeeeeeee222000000000000000000000000000
000000000000000000000000044499111994444000000000000e8888888888888888888088ee0000000000002eeeeeee22222000000000000000000000000000
000000000000000000000000000449999444400000000000000eee8888888888888888888ee0000000000000022eee2222220000000000000000000000000000
00000000000000000000000000004444444400000000000000000ee88888888888888888eee00000000000000022222220000000000000000000000000000000
000000000000000000000000000000000000000000000000000000ee88888888888888eeee000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000eee888888888eeeeee0000000000000000000000000000000000000000000000000000000
000000000000011111100000000000000000000000000000000000000eeeeee88eeeeee000000000000000000000000000000000000333333300000000000000
00000000000111cccc1110000000000000000000000000000000000000eeeeeeeeee0000000000000000000000000000000000003333bbbbb330000000000000
0000000000111cccccc1110000000000000000000000000000000000000000eee0000000000000000000000000000000000000033bbbbbbbbb33000000000000
00000000011ccccccc1cc11000000000000000000000000000000000000000000000000000000000000000000000000000000033bb1bbbbb1bb3300000000000
0000000001cccc11cc11cc110000000000000000000000000000000000000000000000000000000000000000000000000000003bbbbbbbbbbbbb330000000000
0000000011cc111cccc111110000000000000000000000000000000000000000000000000000000000000000000000000000003bbbbbbbbbbbbbb30000000000
000000001cc11cccccccc1c10000000000000000000000000000000000000000000000000000000000000000000000000000003bbbbbbbbbbbbbb30000000000
000000001cccccc1ccccccc10000000000000000000000000000000000000000000000000000000000000000000000000000003bbbbbbbbbbbbbb30000000000
000000001ccccccccc1cccc10000000000000000000000000000000000000000000000000000000000000000000000000000003b11111111111bb30000000000
000000001cccccccccccccc10000000000000000000000000000000000000000000000000000000000000000000000000000003b11bbbbbbbb1bb30000000000
000000001ccc111c1ccc1c1100000000000000000000000000000000000000000000000000000000000000000000000000000033b11bbbbbb11b330000000000
0000000011cc1c111111111000000000000000000000000000000000000000000000000000000000000000000000000000000003bb11bb1111b3330000000000
00000000011cccccccc11110000000000000000000000000000000000000000000000000000000000000000000000000000000033bbb111bbb33300000000000
0000000000111ccccc1111000000000000000000000000000000000000000000000000000000000000000000000000000000000033bbbbbb3333000000000000
000000000001111c1111100000000000000000000000000000000000000000000000000000000000000000000000000000000000033bbb333330000000000000
00000000000011111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000003333333300000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0000000000000000000000000000000000000000000000000000000
0000000000e0000001111111100000000111111110000000011111111000000001111111e0000000000000000000000000000000000000000000000000000000
0000000000e0000001111111100000000111111110000000011111111000000001111111e0000000000000000000000000000000000000000000000000000000
0000000000e0000001111111100000000111111110000000011111111000000001111111e0000000000000000000000000000000000000000000000000000000
0000000000e0000001111111100000000111111110000000011111111000000001111111e0000000000000000000000000000000000000000000000000000000
0000000000e000eee11ee11ee0e0e0eee11e111ee00000eee1e1e1eee0ee000001111111e0000000000000000000000000000000000000000000000000000000
0000000000e000e0e1e1e1e110e0e0e001e111e11000000e01e1e1e1e0e0e00001111111e0000000000000000000000000000000000000000000000000000000
0000000000e111ee10e0e0e001e1e1ee100000eee111111e10e0e0ee01e1e11110000000e0000000000000000000000000000000000000000000000000000000
0000000000e111e1e0e0e0e0e1e1e1e110000000e111111e10e0e0e0e1e1e11110000000e0000000000000000000000000000000000000000000000000000000
0000000000e111e1e0ee00eee11ee1eee00000ee0111111e100ee0e0e1e1e11110000000e0000000000ddddddddddddddddddd00000ddddddddddddddddddd00
0000000000e1111110000000011111111000000001111111100000000111111110000000e0000000000d00000011111111000d00000d00000011111111000d00
0000000000e1111110000000011111111000000001111111100000000111111110000000e0000000000d00000919199911000d00000d00000ccc1ccc11000d00
0000000000e1111110000000011111111000000001111111100000000111111110000000e0000000000d00000919191911000d00000d00000ccc1c1c11000d00
0000000000e1111110000000011111111000000001111111100000000111111110000000e0000000000d00000999199911000d00000d00000c1c1ccc11000d00
0000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0000000000d00000919191111000d00000d00000c1c1c1111000d00
00000000000000000000000000000000000000000000000000000000000000000000000000000000000d00000919191111000d00000d00000c1c1c1111000d00
00000000000000000000000000000000000000000000000000000000000000000000000000000000000d00000011111111000d00000d00000011111111000d00
0000000000ddddddddddddddddddddddddddd0000000000ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
0000111000d8888888888888888888888888d0000000000d0000000011111111000000001111111100000000111111110000000011111111000000001111111d
0000181100d8666866686668666886686868d0000000000d07770777171717770777000011111111000999099911191999099900111ccc1ccc000c0ccc1ccc1d
0111188110d8686886888688686868886868d0000000000d0707070717171171070000001111111100000909111191110909000011111c1c0000c0001c1c111d
0188888810d8666886888688666868886688d0000000000d07700770171711710770000011111111000999099911911999099900111ccc1ccc00c00ccc1ccc1d
0111188110d8686886888688686868886868d0000000000d07070707171711710700000011111111000900001911911900000900111c11110c00c00c11111c1d
0000181100d8686886888688686886686868d0000000000d07770707117711710777000011111111000999099919111999099900111ccc1ccc0c000ccc1ccc1d
0000111000d8888888888888888888888888d0000000000d0111111100000000111111110000000011111111000000001111111100000000111111110000000d
0000000000d1111110000000011111111000d0000000000d0111111100000000111111110000000011111111000000001111111100000000111111110000000d
0000000000d1166166606660666161111000d0000000000d07171777077707001177117707070000111991199900090991199911000c0c0ccc111c1c0c0ccc0d
0000000000d1611116006000616161111000d0000000000d07171717070707001717171107070000111191190000900091191111000c0c0c1c11c11c0c0c0c0d
0000000000d1666116006600666161111000d0000000000d07171777077007001717171107700000111191199900900091199911000ccc0c1c11c11ccc0c0c0d
0000000000d1116116006000616161111000d0000000000d0777171707070700171717110707000011119111090090009111191100000c0c1c11c1110c0c0c0d
0000000000d1661116006660616166611000d0000000000d0777171707070777177111770707000011199919990900099919991100000c0ccc1c11110c0ccc0d
0000000000d1111110000000011111111000d0000000000d0111111100000000111111110000000011111111000000001111111100000000111111110000000d
0000000000d0000001111111100000000111d0000000000d0000000011111111000000001111111100000000111111110000000011111111000000001111111d
0000000000d0666066616661666000000111d0000000000d07070777177717110777077711111111000990099911191990099900111c1c1ccc000c0c1c1ccc1d
0000000000d0060006116111666000000111d0000000000d07070700171717110700070711111111000090091111911190090000111c1c1c0c00c00c1c1c1c1d
0000000000d0060006116611606000000111d0000000000d07770770177717110770077011111111000090099911911190099900111ccc1c0c00c00ccc1c1c1d
0000000000d0060006116111606000000111d0000000000d0707070017171711070007071111111100009000191191119000090011111c1c0c00c0001c1c1c1d
0000000000d0666006116661606000000111d0000000000d0707077717171777077707071111111100099909991911199909990011111c1ccc0c00001c1ccc1d
0000000000d0000001111111100000000111d0000000000d0000000011111111000000001111111100000000111111110000000011111111000000001111111d
0000000000d0000001111111100000000111d0000000000deeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0000000111111110000000011111111000000001111111d
0000000000d1666160006660666111111000d0000000000de777ee77ee77e7e7e777eeeeeeeeeeeee11999199900090999199911000ccc001c1ccc110000000d
0000000000d1611160006000611111111000d0000000000de7e7e7e7e7eee7e7e7eeeeeeeeeeeeeee11119190900900019191911000c0c00c11c1c110000000d
0000000000d1661160006600661111111000d0000000000de77ee7e7e7eee7e7e77eeeeeeeeeeeeee11999190900900999191911000c0c00c11c1c110000000d
0000000000d1611160006000611111111000d0000000000de7e7e7e7e7e7e7e7e7eeeeeeeeeeeeeee11911190900900911191911000c0c00c11c1c110000000d
0000000000d1611166606660666111111000d0000000000de7e7e77ee777ee77e777eeeeeeeeeeeee11999199909000999199911000ccc0c111ccc110000000d
0000000000d1111110000000011111111000d0000000000deeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee1111111000000001111111100000000111111110000000d
0000000000ddddddddddddddddddddddddddd0000000000ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0000000000000101010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0808080808000000000000080808080800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0800000000000000000800000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0800000000000000000800000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0800000000000909090800000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0800000000000906090800000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0800000000000909090800000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
080000000808080808080a0a0000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0800000000000000000a070a0000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0800000000000000000a0a0a0000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0800000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0800000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0800000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0800000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0800000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0800000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0808080808080808080808080808080800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
0001000036510365103b5103f5103f5103f5103f5103d5003d5003b5003f500365003f5003f500345000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
0001000003020040200402005020060200802008020090200a0200b0200c0200d0201002014020170201a0201b0201c020130001400014000150001600016000170001800019000190001b0001c0001d0001e000
0001000011030100300f0300d0300b0300a02008020060100400008000060000400004000090000d0000800008000060000a0000a000090000800007000070000000000000000000000000000000000000000000
000100000a55003500355000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
0001000020640206402064021640216403a340393303533031330303302f3302e3102c3102a310263101f3101b31018310143100f3100b3100000000000000000000000000000000000000000000000000000000
0003000005620026200f62008620156201a6200f32026420173202142012320264201a320304201c32034420253202f4201630008600086000760007600076000960006600056000560005600056000360002600
011000000c3100c3001d3101c3101c3001c3001f3101d3000c3100c3001d310143101c3001d300133101c3100c3100c3001d3101c3101c3001c300203101d3000c3100c3001d310143101c3101d3101431013310
0110000024225182251f225202251c2251c2251f2252222520225222251f2251f2251c2251c22519225182251c2251c2251d2251f2251d2251d2251d225202251f2251f2251f22520225202251f2251d2251c225
0110000013313376152e2151331337615133132e2153761513313133132c2151331337615133132c21513313133133761529215133133761537615292153761513313376152b2151331337615376153761537615
0110000024712297122c7122e712247122b7122e71230712247122b7122e71230712247122b7123071231712287122b712307123171228712297122e71230712297122b7122e712307122b712297122871225712
00010000056102f6102161002610386101b610056102d6103a6103761010610216102e6103c6102661009610316103b6102061024610146100a6103e610246101e6102d6103e6101c61009610386103461002610
01010000000003a0503a0503905000000380500000000000350503d05000000320500000039050000002d0500000036050000003405027050330500000022050000001f050290501a050150500d0500805003050
0110000007543376252e2100754337625133002e2102e21507543133002c2100754337625075432c2102c215075433760029210075433762537600292102921507543376252b2100754337625376002b21037625
__music__
01 06474844
00 06474844
00 06420944
00 07420944
00 07060c49
00 07060c49
00 47420c44
00 090c4844
00 47060c09
00 07060c09
02 07060c09
02 47464849
02 47464849
02 47464849
02 47464849
02 47464849


