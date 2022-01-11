pico-8 cartridge // http://www.pico-8.com
version 29
__lua__


loops = {
    game = 'game',
}

current_loop = nil;

function _init()
    music(0)
    current_loop = loops.game
end
function _update60()
    if(current_loop == loops.game)game_update()
end
function _draw()
    if(current_loop == loops.game)game_draw()
end

--game constants
conv_h = 120
conv_l = 128
conv_w = 3

conv_lines = 10

box_h = 15
box_w = 20

box_spawn_rate = 150
food_spawn_rate = 50
spawn_buf = 60

grav = 0.05

speeds = {
    stop = 0,
    slow = 0.5,
    fast = 1
}

foods = {
    'banana',
    'apple',
    'bread',
    'egg'
}

foodspr = {
    banana = 1,
    apple = 2,
    bread = 3,
    egg = 4
}

--vars
current_speed = speeds.fast
g_t = 0
buf_t = 0;
next_queue={};

boxes = {}
flyers = {}


function game_update()
    g_t += current_speed
    if(btn(4))current_speed = speeds.stop
    if(btn(5))current_speed = speeds.fast
    if(not btn(4) and not btn(5)) current_speed = speeds.slow
    for b in all(boxes) do
        b.x += current_speed;
        if b.x > -box_w and not b.on then
         b.on = true
         del(next_queue, next_queue[1])
        end
        if(b.x > 128) del(boxes, b)
    end
    if buf_t > 0 then
        buf_t -= 1
    else
        if rnd(box_spawn_rate * current_speed) < 1 then
            local t = foods[flr(rnd(#foods))+1]
            add(boxes, {x=-50, on=false, t=t})
            add(next_queue, t)
            buf_t += spawn_buf
        end
    end

    if rnd(food_spawn_rate) < 1 then
        add(flyers, {x=130, y=rnd(50) + 30, xvel= rnd(3) - 3, yvel = rnd(2) - 2, t=foods[flr(rnd(#foods))+1]})
    end

    for f in all(flyers) do
        f.x += f.xvel
        f.yvel += grav
        f.y += f.yvel
        if(f.y < 0) del(flyers, f)
    end
end

function game_draw()
    cls(2)

    for f in all(flyers) do
        spr(foodspr[f.t], f.x, f.y)
    end

    rectfill(0,conv_h, conv_l, conv_h + conv_w, 0)

    for i = 1, conv_lines do
        local x = (i * (conv_l / conv_lines) + g_t) % conv_l 
        line(x, conv_h, x-3, conv_h, 9)
        line(conv_l - x, conv_h + conv_w, conv_l - x + 3, conv_h + conv_w, 9)
    end

    for b in all(boxes) do
        local x = b.x
        local y = conv_h - box_h
        rectfill(x, y, x + box_w, conv_h - 1, 4)
        spr(foodspr[b.t], x + box_w /2 - 4, y + box_h/2 - 4)
    end

    if #next_queue > 0 then
        local x = sin(time()) * 5
        spr(5, x + 8, 90)
        spr(foodspr[next_queue[1]], x + 16, 90)
    end


end




__gfx__
00000000000000900003300000099000000770000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000a00000300000994900007777000008800000000000000000000000000000000000000000000000000000000000000000000000000000000000
0070070000000aaa0088880000949900007777000888800000000000000000000000000000000000000000000000000000000000000000000000000000000000
0007700000000aaa0888878000999900077777708888888800000000000000000000000000000000000000000000000000000000000000000000000000000000
000770000000aa7a0888878000994900077776700888800000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000aa7a00888888000949900077776700008800000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000aaaaa000888888000999900077767700000800000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000aaa0000088880000099000007777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
011000000c0150c0150c0150c0151001510015130151301510015100151001510015130151301510015100150c0150c0150c0150c015100151001513015130150e0150e0150e0150e01511015110151301513015
011000000c7120c7120c7120c71210712107121071210712137121371213712137120e7120e7120e7120e7120c7120c7120c7120c71210712107121071210712157121571215712157120e7120e7120e7120e712
__music__
03 00014344

