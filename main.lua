io.stdout:setvbuf("no")

function init_board(top_x, top_y, side, pawn_radius)
    BOARD = {
        top_x = top_x,
        top_y = top_y,
        side = side,
        min_x = top_x,
        pawn_radius = pawn_radius
    }
    generate_board_positions()
    generate_board_pawns()   
end

function generate_board_positions()
    BOARD.max_x = BOARD.top_x + 3*BOARD.side
    BOARD.max_y = BOARD.top_y + 3*BOARD.side
    BOARD.cells_coord = {}
    for i=1,3 do
        row = {}
        for j=1,3 do
            table.insert(row, {BOARD.top_x + j*BOARD.side, BOARD.top_y + i*BOARD.side})
        end
        table.insert(BOARD.cells_coord, row)
    end
end

function color_to_string(col)
    if col==WHITE then
        return "W"
    elseif col==BLACK then
        return "B"
    elseif col==nil then
        return "0"
    else
        return ""
    end
end

function pawn_color_to_string(pwn)
    if pwn == nil then
        return color_to_string(nil)
    end
    return color_to_string(pwn.color)
end

function board_cells_coord_to_string(invert_cols)
    invert_cols = invert_cols or false -- default arg
    s = ""
    if invert_cols then
        for i=1,3 do
            for j=3,1,-1 do
                s = s .. pawn_color_to_string(get_pawn_cell(i, j))
            end
        end
    else
        for i=1,3 do
            for j=1,3 do
                s = s .. pawn_color_to_string(get_pawn_cell(i, j))
            end
        end
    end
    return s
end

function invert_board_representation(representation) 
    local repr_reverse = ""
    for i=1,7,3 do
        repr_reverse = repr_reverse .. string.reverse(string.sub(representation, i, i+2))
    end
    return repr_reverse
end

function symmetric(cell)
    sim_row = cell[1]
    sim_col = 4 - cell[2]
    return {sim_row, sim_col}
end

function center_of_cell(i, j)
    half_side = BOARD.side/2
    return {BOARD.cells_coord[i][j][1] - half_side, BOARD.cells_coord[i][j][2] - half_side}
end

function new_pawn(index, cell, color)
    cell_ctr = center_of_cell(cell[1], cell[2])
    pawn = {
        idx = index,
        cell = cell,
        ctr_x = cell_ctr[1],
        ctr_y = cell_ctr[2],
        selected = false,
        captured = false,
        color = color
    }
    return pawn
end

function capture_pawn(pawn)
    pawn.cell = nil
    pawn.ctr_x = 0
    pawn.ctr_y = 0
    pawn.selected = false
    pawn.captured = true
end

function generate_board_pawns()
    BOARD.pawns = {}
    BOARD.cells_status = {}
    pawn_index = 1
    for i=1,3 do
        color = nil
        if i == 1 then
            color = BLACK
            table.insert(BOARD.cells_status, {1,2,3})
        elseif i == 3 then
            color = WHITE
            table.insert(BOARD.cells_status, {4,5,6})
        else
            table.insert(BOARD.cells_status, {0,0,0})
        end
        for j=1,3 do
            if i ~= 2 then
                pawn = new_pawn(pawn_index, {i,j}, color)
                table.insert(BOARD.pawns, pawn)
                pawn_index = pawn_index + 1
            end
        end
    end
end

function refresh_cells_status()
    for i=1,3 do
        cell_status = {}
        for j=1,3 do
            table.insert(cell_status, get_pawn_cell(i,j) or 0)
        end
        table.insert(BOARD.cells_status, cell_status)
    end
end


function get_pawn_cell(row, col)
    pawn_occupying = BOARD.cells_status[row][col]
    if pawn_occupying == 0 then
        return nil
    else
        return BOARD.pawns[pawn_occupying]
    end
end

function board_cell_clicked(x, y)
    if x >= BOARD.top_x and x <= BOARD.max_x and y >= BOARD.top_y and y <= BOARD.max_y then
        for i=1,3 do
            for j=1,3 do
                if x < BOARD.cells_coord[i][j][1] and y < BOARD.cells_coord[i][j][2] then
                    pawn_occ = get_pawn_cell(i, j)
                    return {pawn_occ, {i, j}}
                end
            end
        end
    else
        return nil
    end
end

function add_move_if_legal(pawn_move, destination, tbl_moves)
    destination_status = {get_pawn_cell(destination[1], destination[2]), destination}
    -- print("Pawn position", pawn_move.cell[1], pawn_move.cell[2], "TO", destination[1], destination[2])
    if is_legal_move(pawn_move.cell, destination_status, pawn_move) then
        -- print("Legal move, adding")
        table.insert(tbl_moves, destination)
    end
end

function get_legal_moves(pawn_move)
    row_additive = -1
    if pawn_move.color == BLACK then
       row_additive = 1 
    end

    pawn_row = pawn_move.cell[1]
    pawn_col = pawn_move.cell[2]


    moves = {}
    -- move in front, always possible if pawn not obstructed
    add_move_if_legal(pawn_move, {pawn_row + row_additive, pawn_col}, moves)
    
    if pawn_col>1 then -- pawn is central or left
        add_move_if_legal(pawn_move, {pawn_row + row_additive, pawn_col - 1}, moves)
    end
    if pawn_col<3 then -- pawn is central or right
        add_move_if_legal(pawn_move, {pawn_row + row_additive, pawn_col + 1}, moves)
    end
    return moves
end

function rollback_move(cell_origin, pawn_move)
    local old_center = center_of_cell(cell_origin[1], cell_origin[2])
    pawn_move.ctr_x = old_center[1]
    pawn_move.ctr_y = old_center[2]
end

function execute_move(cell_origin, destination_status, pawn_move)
    o_row = cell_origin[1]
    o_col = cell_origin[2]
    dest_row = destination_status[2][1]
    dest_col = destination_status[2][2]
    pawn_dest = destination_status[1]

    BOARD.cells_status[o_row][o_col] = 0
    BOARD.cells_status[dest_row][dest_col] = pawn_move.idx
    new_center = center_of_cell(dest_row, dest_col)
    pawn_move.ctr_x = new_center[1]
    pawn_move.ctr_y = new_center[2]
    pawn_move.cell = destination_status[2]

    if pawn_dest ~= nil then
        capture_pawn(pawn_dest)
    end
end

function is_legal_move(cell_origin, destination_status, pawn_move)
    o_row = cell_origin[1]
    o_col = cell_origin[2]
    dest_row = destination_status[2][1]
    dest_col = destination_status[2][2]
    pawn_dest = destination_status[1]

    --print("FROM", o_row, o_col, "TO", dest_row, dest_col, "Pawn destination", pawn_dest)
    if o_row == dest_row and o_col == dest_col then
        return false
    elseif o_col == dest_col and 
          ((dest_row == o_row - 1 and pawn_move.color == WHITE) or (dest_row == o_row + 1 and pawn_move.color == BLACK)) then
        -- mossa in su
        -- controlla se cella libera
        return pawn_dest == nil
    elseif (o_col + 1 == dest_col or o_col - 1 == dest_col) and 
           ((dest_row == o_row - 1 and pawn_move.color == WHITE) or (dest_row == o_row + 1 and pawn_move.color == BLACK)) then
        -- mossa in diagonale
        -- controlla se cella occupata e di altro colore
        return (pawn_dest ~= nil and pawn_dest.color ~= pawn_move.color)
    end
end

function check_victorious_move(pawn_move)
    -- raggiunta fine scacchiera
    if (pawn_move.color == BLACK and pawn_move.cell[1] == 3) or (pawn_move.color == WHITE and pawn_move.cell[1] == 1) then
        return true
    end
    -- 0 pedine nemiche
    enemy_pawns = {}
    for i,p in ipairs(BOARD.pawns) do
        if p.color ~= pawn_move.color and not p.captured then
            table.insert(enemy_pawns, p)
        end
    end
    if #enemy_pawns == 0 then
        return true
    end
    
    -- no mosse legali
    exist_legal_moves = false
    for i,p in ipairs(enemy_pawns) do
        moves = get_legal_moves(p)
        if #moves > 0 then
            exist_legal_moves = true
            break
        end
    end
    return not exist_legal_moves
end

function insert_db_moves(board_repr)
    print("Inserting for board " .. board_repr)

    moves_current = {}
    moves_symmetric = {}

    for i,p in ipairs(BOARD.pawns) do
        if p.color == BLACK and not p.captured then
            legal_moves_pawn = get_legal_moves(p)
            max_legal_moves = #legal_moves_pawn
            
            for j, mv in ipairs(legal_moves_pawn) do
                if j>max_legal_moves then
                    break
                end
                table.insert(moves_current, {origin = p.cell,  destination = mv, enabled = true})
                table.insert(moves_symmetric, {origin = symmetric(p.cell),  destination = symmetric(mv), enabled = true})
            end
        end
    end

    DB_MOVES[board_repr] = moves_current
    board_repr_symmetric = board_cells_coord_to_string(true)
    if board_repr_symmetric ~= board_repr then
        DB_MOVES[board_repr_symmetric] = moves_symmetric
    end
end

function compare_db_moves(first, second)
    return (first.origin[1] == second.origin[1] and first.origin[2] == second.origin[2]
       and first.destination[1] == second.destination[1] and first.destination[2] == second.destination[2])
end

function filter_possible_moves(board_repr)
    -- possible moves is an array of the shape
    -- {{pawn_id = , destination = }, ...}
    possible_moves = {}

    for i, mv in ipairs(DB_MOVES[board_repr]) do
        if mv.enabled then
            table.insert(possible_moves, {origin = mv.origin, destination = mv.destination})
        end
    end

    -- print("POSSIBLE MOVES")
    -- for i, mv in ipairs(possible_moves) do
    --     print(mv.origin[1], mv.origin[2], mv.destination[1], mv.destination[2])
    -- end
    return possible_moves
end

function select_move_black()
    -- get configuration as a string
    board_repr = board_cells_coord_to_string()
    print("Board repr obtained " .. board_repr, "KEYS PRESENT:")

    for k,v in pairs(DB_MOVES) do
        print(k)
    end

    -- if moves for the corresponding configuration do not exist, create a db entry for self and symmetric
    if DB_MOVES[board_repr] == nil then
        insert_db_moves(board_repr)
    end

    -- select enabled moves
    possible_moves = filter_possible_moves(board_repr)

    if #possible_moves > 0 then
        move_id = love.math.random(#possible_moves)
        -- print("Extracted", move_id)
        return {move=possible_moves[move_id], repr=board_repr}
    end
    return nil
end

function move_black()
    selected_move = select_move_black()
    local orig_dest = selected_move.move
    
    if orig_dest == nil then -- no possible move
        end_game(1)
    else
        origin = orig_dest.origin
        moving_pawn = get_pawn_cell(origin[1], origin[2])
        destination = orig_dest.destination
        destination_status = {get_pawn_cell(destination[1], destination[2]), destination}
        execute_move(origin, destination_status, moving_pawn)
        BLACK_LAST_MOVE = selected_move
        if check_victorious_move(moving_pawn) then
            end_game(2)
        end
    end
    end_move()
end

function log(text, color)
    if color == nil then
        color = COLOR_LOG_TEXT
    end
    local xtext = LOG_MSG_X
    local ytext = LOG_MSG_Y + LOG_MSG_YDIFF * (LOG_N)
    LOG_N = LOG_N + 1
    table.insert(LOG_MESSAGES, {x=xtext, y=ytext, text=text, color=color})
end

function end_move()
    MOVE_ID = MOVE_ID + 1
    refresh_cells_status()
    if TURN == BLACK then
        TURN = WHITE
    else
        TURN = BLACK
    end
end

function disable_black_losing_move()
    local reprs = {BLACK_LAST_MOVE.repr, invert_board_representation(BLACK_LAST_MOVE.repr)}
    for k, repr in ipairs(reprs) do
        local origin = BLACK_LAST_MOVE.move.origin
        local destin = BLACK_LAST_MOVE.move.destination
        if k==2 then
            origin = symmetric(origin)
            destin = symmetric(destin)
        end
        local moves_entries = DB_MOVES[repr]
        for i,mv in ipairs(moves_entries) do
            if compare_db_moves({origin=origin, destination=destin}, mv) then
                mv.enabled = false
            end
        end
    end
end

function end_game(player_victory)
    GAME_ENDED = true
    local s = "Partita " .. GAME_ID + 1
    local col = nil
    if player_victory == 1 then
        s = s .. ". Vittoria del giocatore."
        W_PLAYER = W_PLAYER + 1
        disable_black_losing_move()
    else
        s = s .. ". Vittoria del computer."
        col = COLOR_DEFEAT
    end
    log(s, col)
    GAME_ID = GAME_ID + 1
end

function draw_checkerboard()
    for i=0,2 do
        for j=0,2 do
            -- draw fill then edge
            -- fill color depends upon index odd or even
            if (i+j)%2 == 0 then
                love.graphics.setColor(COLOR_LIGHT)
            else
                love.graphics.setColor(COLOR_DARK)
            end
            love.graphics.rectangle("fill", BOARD.top_x + i*BOARD.side, BOARD.top_y+ j*BOARD.side, BOARD.side, BOARD.side)
            -- line is always dark blue
            love.graphics.setColor(COLOR_EDGE)
            love.graphics.rectangle("line", BOARD.top_x + i*BOARD.side, BOARD.top_y+ j*BOARD.side, BOARD.side, BOARD.side)
        end
    end
end

function draw_pawns()
    for i,pawn in ipairs(BOARD.pawns) do
        if not pawn.captured then
            love.graphics.setColor(pawn.color)
            love.graphics.circle("fill", pawn.ctr_x, pawn.ctr_y, BOARD.pawn_radius)
        end
    end
end

function init_all()
    local top_x = 50
    local top_y = 50
    local block_side = 100
    local pawn_radius = block_side * 0.4  

    BOARD = {}
    init_board(top_x, top_y, block_side, pawn_radius)

    GAME_ID = 0
    W_PLAYER = 0
    
    DB_MOVES = {}
    BLACK_LAST_MOVE = {}

    LOG_X = 400
    LOG_Y = 100
    LOG_LEN = 300
    LOG_HEI = 300
    LOG_MSG_X = LOG_X + 10
    LOG_MSG_Y = LOG_Y + 10
    LOG_MSG_YDIFF = 20
    LOG_N = 0
    LOG_MESSAGES = {}

    STATS_X = LOG_X + 10
    STATS_Y = LOG_Y + LOG_HEI + 20
    STATS_YDIFF = 25
    love.math.setRandomSeed( love.timer.getTime()*1000 )

    init_game()
end

function init_game()
    generate_board_pawns()

    DRAGGING_STATS = {idx=0, diffx=0, diffy=0, cell_origin=nil}
    
    TURN = WHITE
    MOVE_ID = 0
    GAME_ENDED = false
    CAN_MOVE_BLACK = true
end

function love.load()
    
    BLACK = {0,0,0}
    WHITE = {1,1,1}
    COLOR_DARK = {132/255, 151/255, 176/255}
    COLOR_LIGHT = {189/255, 215/255, 238/255}
    COLOR_EDGE = {8/255, 30/255, 138/255}

    COLOR_BTN_DISABLED = {220/255, 232/255, 224/255}
    COLOR_BTN_ENABLED = BLACK
    COLOR_BACKGROUND = WHITE

    COLOR_LOG_EDGE = BLACK
    COLOR_LOG_TEXT = BLACK

    COLOR_DEFEAT = {1, 0, 0}
    
    love.graphics.setBackgroundColor(COLOR_BACKGROUND)

    init_all()
end

function draw_btn()
    love.graphics.setColor(BLACK)
    love.graphics.rectangle("fill", 10, 550, 50, 20)
    love.graphics.setColor(WHITE)
    love.graphics.print("canmove", 12, 552)
end

function draw_restart()
    love.graphics.setColor(COLOR_BTN_ENABLED)
    love.graphics.rectangle("fill", 80, 550, 60, 20)
    love.graphics.setColor(WHITE)
    love.graphics.print("RESET", 82, 552)
end

function draw_continue()
    if GAME_ENDED then
        love.graphics.setColor(COLOR_BTN_ENABLED)
    else
        love.graphics.setColor(COLOR_BTN_DISABLED)
    end
    love.graphics.rectangle("fill", 160, 550, 70, 20)
    love.graphics.setColor(WHITE)
    love.graphics.print("CONTINUA", 162, 552)
end

function draw_log_container()
    love.graphics.setColor(COLOR_LOG_EDGE)
    love.graphics.rectangle("line", LOG_X, LOG_Y, LOG_LEN, LOG_HEI)
end

function draw_log_messages()
    for i,msg in ipairs(LOG_MESSAGES) do
        love.graphics.setColor(msg.color)
        love.graphics.print(msg.text, msg.x, msg.y)
    end
end

function draw_stats()
    love.graphics.setColor(BLACK)
    local statline1 = "Nr. partite giocate: " .. GAME_ID
    love.graphics.print(statline1, STATS_X, STATS_Y)
    local pctw = 0.0
    if GAME_ID > 0 then
        pctw = W_PLAYER / GAME_ID
    end
    local statline2 = "Nr. partite vinte dal giocatore: " .. W_PLAYER .. string.format(" (%.2f", pctw*100) .. "%)"
    love.graphics.print(statline2, STATS_X, STATS_Y + STATS_YDIFF)
    if GAME_ID > 0 then
        pctw = 1 - pctw
    end
    local statline3 = "Nr. partite vinte dal computer: " .. (GAME_ID - W_PLAYER) .. string.format(" (%.2f", pctw*100) .. "%)"
    love.graphics.print(statline3, STATS_X, STATS_Y + 2*STATS_YDIFF)
end


function love.draw()
    draw_checkerboard()
    draw_pawns()
    -- draw_btn()
    draw_restart()
    draw_continue()
    draw_log_container()
    draw_log_messages()
    draw_stats()
end

function love.mousepressed(x, y, button)
    if button == 1 then
        if TURN == WHITE and not GAME_ENDED then
            moving_data = board_cell_clicked(x, y)
            if moving_data ~= nil then
                pawn = moving_data[1]
                cell_origin = moving_data[2]
                if pawn == nil then
                    -- nothing for now
                else
                    if pawn.color == WHITE then
                        DRAGGING_STATS.idx = pawn.idx
                        DRAGGING_STATS.diffx = x - pawn.ctr_x
                        DRAGGING_STATS.diffy = y - pawn.ctr_y
                        DRAGGING_STATS.cell_origin = cell_origin
                    end
                end
            end
        end
        -- --canmove
        -- if y>550 and y<570 and x>10 and x<60 then
        --     CAN_MOVE_BLACK = not CAN_MOVE_BLACK
        -- end

        --restart
        if y>500 and y<570 and x>80 and x<140 then
            init_all()
        end
        --continue
        if y>550 and y<570 and x>160 and x<230 and GAME_ENDED then
            init_game()
            debug_print_DB()
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then
        if DRAGGING_STATS.idx > 0 then
            moving_pawn = BOARD.pawns[DRAGGING_STATS.idx]
            new_cell_stats = board_cell_clicked(x, y)
            if new_cell_stats ~= nil then
                destination_cell = new_cell_stats[2]
                if is_legal_move(DRAGGING_STATS.cell_origin, new_cell_stats, moving_pawn) then
                    execute_move(cell_origin, new_cell_stats, moving_pawn)
                    if check_victorious_move(moving_pawn) then
                        end_game(1)
                    end
                    end_move()
                else
                    rollback_move(cell_origin, moving_pawn)
                end
            else
                rollback_move(cell_origin, moving_pawn)
            end
            DRAGGING_STATS.idx = 0
            
        end
    end
end

function love.update(dt)
    if DRAGGING_STATS.idx > 0 then
        pawn = BOARD.pawns[DRAGGING_STATS.idx]
        pawn.ctr_x = love.mouse.getX() - DRAGGING_STATS.diffx
        pawn.ctr_y = love.mouse.getY() - DRAGGING_STATS.diffy
    end
    if TURN == BLACK and CAN_MOVE_BLACK and not GAME_ENDED then
        move_black()
    end
end

function debug_print_DB()
    for r, entries in pairs(DB_MOVES) do
        print("Representation " .. r)
        for i, vals in ipairs(entries) do
            print("FROM", "(" .. vals.origin[1] .. "," .. vals.origin[2] .. ")", "TO",
                    "(" .. vals.destination[1] .. "," .. vals.destination[2] .. ")", "ENABLED: ", vals.enabled)
        end
    end
end