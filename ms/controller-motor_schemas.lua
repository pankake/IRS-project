
local vector = require "vector"

local LIGHT_THRESHOLD = 0 -- soglia per determinare se la sorgente luminosa è significativa
local NO_LIGHT_STEPS_THRESHOLD = 100 -- numero di step dopo i quali inizia il movimento casuale
local PROXIMITY_THRESHOLD = 0.2 -- soglia per determinare se l'ostacolo è vicino

local light_vector = {x = 0, y = 0} -- vettore per la fototassi
local proximity_vector = {x = 0, y = 0} -- vettore per l'evitamento degli ostacoli
local random_vector = {x = 0, y = 0} -- vettore per il movimento casuale
local step_counter = 0 -- contatore per il numero di step senza luce
local random_movement_mode = false -- modalità di movimento casuale
local random_movement_step_counter = 0 -- contatore per il numero di step in movimento casuale

-- fototassi: muove il robot verso la luce
function phototaxis()
    local light_readings = robot.light
    local cAccumulatorX = 0
    local cAccumulatorY = 0

    -- calcola la somma dei vettori di luce
    for i = 1, #light_readings do
        local sensor_value = light_readings[i].value
        local sensor_angle = light_readings[i].angle
        cAccumulatorX = cAccumulatorX + sensor_value * math.cos(sensor_angle)
        cAccumulatorY = cAccumulatorY + sensor_value * math.sin(sensor_angle)
    end

    -- assegna i valori alla variabile globale
    light_vector.x = cAccumulatorX
    light_vector.y = cAccumulatorY

    -- calcola la lunghezza del vettore risultante
    local resultant_length = vector.vec2_length({x = cAccumulatorX, y = cAccumulatorY})

    -- controlla se l'angolo risultante è maggiore della soglia
    if resultant_length > LIGHT_THRESHOLD then
        step_counter = 0 -- resetta il contatore se viene rilevata luce
        random_movement_mode = false -- esce dalla modalità di movimento casuale
    else
        step_counter = step_counter + 1 -- incrementa il contatore se non viene rilevata luce
        if step_counter > NO_LIGHT_STEPS_THRESHOLD then
            random_movement_mode = true -- entra nella modalità di movimento casuale
        end
    end
end

-- evita l'ostacolo
function avoid_obstacle()
    local proximity_readings = robot.proximity
    local cAccumulatorX = 0
    local cAccumulatorY = 0

    -- utilizza solo i sensori frontali (1-6 e 19-24)
    for i = 1, 6 do
        local sensor_value = proximity_readings[i].value
        local sensor_angle = proximity_readings[i].angle
        cAccumulatorX = cAccumulatorX + sensor_value * math.cos(sensor_angle)
        cAccumulatorY = cAccumulatorY + sensor_value * math.sin(sensor_angle)
    end
    for i = 19, 24 do
        local sensor_value = proximity_readings[i].value
        local sensor_angle = proximity_readings[i].angle
        cAccumulatorX = cAccumulatorX + sensor_value * math.cos(sensor_angle)
        cAccumulatorY = cAccumulatorY + sensor_value * math.sin(sensor_angle)
    end

    -- assegna i valori al vettore per l'evitamento degli ostacoli
    proximity_vector.x = -cAccumulatorX -- nega i valori per ottenere una repulsione
    proximity_vector.y = -cAccumulatorY

    -- calcola la lunghezza del vettore risultante
	local resultant_length = vector.vec2_length({x = cAccumulatorX, y = cAccumulatorY})

end

-- movimento casuale
function random_movement()
    if random_movement_step_counter == 0 then
        local random_angle = math.random() * 2 * math.pi - math.pi -- angolo casuale tra -pi e pi
        local random_magnitude = math.random(1, 10) -- magnitudo casuale
		random_vector = vector.vec2_new_polar(random_magnitude, random_angle)
    end

    random_movement_step_counter = random_movement_step_counter + 1
    if random_movement_step_counter > 20 then -- reset dopo un certo numero di step
        random_movement_step_counter = 0
    end
end

-- movimento lungo i muri
function wall_following()
    local vtr = {length = 0, angle = 0}
    local value = -1 -- valore più alto trovato finora
    local idx = -1   -- indice del valore più alto

    -- trova il sensore di prossimità con il valore più alto
    for i = 1, #robot.proximity do
        if value < robot.proximity[i].value then
            idx = i
            value = robot.proximity[i].value
        end
    end

    -- calcola l'angolo e la lunghezza del vettore
    if idx >= 0 then
        local angle = robot.proximity[idx].angle
        if angle <= 0 then
            vtr.angle = angle + math.pi / 2
            vtr.length = value
        else
            vtr.angle = angle - math.pi / 2
            vtr.length = value
        end
    else
        vtr.length = 0
        vtr.angle = 0
    end

    return vtr
end

-- funzione per la composizione dei vettori
function motor_schemas()
    local resultant_vector = {x = 0, y = 0}
    local weight_light = 1
    local weight_proximity = 2 
    local weight_random = 0.5
    local weight_wall_following = 1.5 

    -- calcola il vettore di movimento lungo i muri
    local wall_following_vector = wall_following()
    local wall_following_vector_cartesian = vector.vec2_new_polar(wall_following_vector.length, wall_following_vector.angle)

    -- somma dei vettori pesati
    resultant_vector = vector.vec2_sum(
        resultant_vector,  -- vettore risultante parziale
        vector.vec2_sum(
            vector.vec2_sum(
                vector.vec2_sum(
                    {x = weight_light * light_vector.x, y = weight_light * light_vector.y},  -- vettore di fototassi
                    {x = weight_proximity * proximity_vector.x, y = weight_proximity * proximity_vector.y}  -- vettore di prossimità
                ),
                {x = weight_random * random_vector.x, y = weight_random * random_vector.y}  -- vettore casuale
            ),
            {x = weight_wall_following * wall_following_vector_cartesian.x, y = weight_wall_following * wall_following_vector_cartesian.y}  -- vettore di movimento lungo i muri
        )
    )

    return resultant_vector
end

-- funzione per controllare gli attuatori
function actuator()

    if random_movement_mode then
        random_movement() -- esegue il movimento casuale
    else
        -- azzera il vettore se il movimento casuale non è attivo
        random_vector = {x = 0, y = 0}
    end

    local resultant_vector = motor_schemas()
    local resultant_angle = vector.vec2_angle({y = resultant_vector.y, x = resultant_vector.x})
    local resultant_magnitude = vector.vec2_length(resultant_vector)

    -- se il valore risultante è significativo, allora regola la velocità delle ruote
    if resultant_magnitude > 0 then
        local left_speed = 10 * (1 - resultant_angle / 4) -- la divisione per 4 attenua l'angolo complessivo
        local right_speed = 10 * (1 + resultant_angle / 4)
        robot.wheels.set_velocity(left_speed, right_speed)
    else
        robot.wheels.set_velocity(10, 10) -- se non ci sono spostamenti da compiere, allora va dritto
    end
end



-- funzione principale per eseguire i comportamenti in sequenza
function main_controller()
    phototaxis()           	-- esegue la fototassi
    avoid_obstacle()   		-- esegue il comportamento di evitamento degli ostacoli
    wall_following()     	-- esegue il comportamento di movimento lungo i muri
    actuator()           	-- controllo degli attuatori
end


function init()
    
end


function step()
    main_controller()    -- chiama il main controller ad ogni step
end

function reset()
    step_counter = 0
    random_movement_mode = false
    random_movement_step_counter = 0
    light_vector = {x = 0, y = 0}
    proximity_vector = {x = 0, y = 0}
    random_vector = {x = 0, y = 0}
end

function destroy()
	x = robot.positioning.position.x
	y = robot.positioning.position.y
	d = math.sqrt((x-1.5)^2 + y^2)
	print('f_distance ' .. d)
end
