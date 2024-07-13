local LIGHT_THRESHOLD = 0 -- soglia per determinare se la sorgente luminosa è significativa
local NO_LIGHT_STEPS_THRESHOLD = 100 -- numero di step dopo i quali inizia il movimento casuale
local PROXIMITY_THRESHOLD = 0.25 -- soglia per determinare se l'ostacolo è abbastanza vicino

local light_angle = 0 -- variabile globale per memorizzare l'angolo di luce calcolato
local step_counter = 0 -- contatore per il numero di step senza luce
local random_movement_mode = false -- modalità di movimento casuale
local random_movement_step_counter = 0 -- contatore per il numero di step in movimento casuale
local proximity_avoidance_angle = 0 -- angolo per evitare gli ostacoli
local proximity_resultant_length = 0 -- lunghezza del vettore di prossimità risultante
local wall_following_vector = {length = 0, angle = 0} -- vettore per seguire i muri

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

    -- calcola l'angolo risultante del vettore di luce
    local resultant_angle = math.atan2(cAccumulatorY, cAccumulatorX)
    local resultant_length = math.sqrt(cAccumulatorX^2 + cAccumulatorY^2)

    -- controlla se l'angolo risultante è maggiore della soglia
    if resultant_length > LIGHT_THRESHOLD then
        light_angle = resultant_angle -- memorizza l'angolo risultante
        step_counter = 0 -- resetta il contatore se viene rilevata luce
        random_movement_mode = false -- esce dalla modalità di movimento casuale
    else
        light_angle = 0 -- resetta l'angolo se è inferiore alla soglia
        step_counter = step_counter + 1 -- incrementa il contatore se non viene rilevata luce
        if step_counter > NO_LIGHT_STEPS_THRESHOLD then
            random_movement_mode = true -- entra nella modalità di movimento casuale
        end
    end
end

-- funzione per seguire i muri
function wall_following()
    local vtr = {length = 0, angle = 0}
    local value = -1 -- valore massimo trovato finora
    local idx = -1 -- indice del valore massimo

    for i = 1, 24 do
        if value < robot.proximity[i].value then
            idx = i
            value = robot.proximity[i].value
        end
    end

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

    wall_following_vector = vtr
end

-- calcola i dati dei sensori di prossimità frontali
function compute_proximity()
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

    -- calcola l'angolo risultante del vettore di prossimità
    local resultant_angle = math.atan2(cAccumulatorY, cAccumulatorX)
    local resultant_length = math.sqrt(cAccumulatorX^2 + cAccumulatorY^2)

    -- se viene rilevato un ostacolo significativo, memorizza l'angolo e la lunghezza per evitare
    if math.abs(resultant_length) > PROXIMITY_THRESHOLD then
        proximity_avoidance_angle = resultant_angle
        proximity_resultant_length = resultant_length -- memorizza la lunghezza del vettore
    else
        proximity_avoidance_angle = 0 -- resetta l'angolo di evitamento se non ci sono ostacoli
        proximity_resultant_length = 0
    end

end

-- movimento casuale
function random_movement()
    -- se rileva un ostacolo significativo, evita l'ostacolo
    if proximity_avoidance_angle ~= 0 then
        -- più vicino è l'ostacolo, più forte sarà la rotazione
        local avoidance_factor = math.min(proximity_resultant_length / PROXIMITY_THRESHOLD, 1)
        local left_speed = 10 * (1 + 2 * avoidance_factor * proximity_avoidance_angle / math.pi)
        local right_speed = 10 * (1 - 2 * avoidance_factor * proximity_avoidance_angle / math.pi)
        robot.wheels.set_velocity(left_speed, right_speed)
        return
    end

    -- se non c'è un ostacolo, continua con il movimento casuale
    local random_angle = math.random() * 2 * math.pi - math.pi -- angolo casuale tra -pi e pi
    local forward_steps = math.random(5, 20) -- numero casuale di step per muoversi in avanti
    local curve_steps = math.random(5, 10) -- numero casuale di step per curvare

    if random_movement_step_counter < forward_steps then
        robot.wheels.set_velocity(10, 10) -- muove in avanti
    elseif random_movement_step_counter < forward_steps + curve_steps then
        local left_speed = 10 * (1 - random_angle / 4) -- riduci l'angolo di curvatura
        local right_speed = 10 * (1 + random_angle / 4)
        robot.wheels.set_velocity(left_speed, right_speed) -- curva
    else
        random_movement_step_counter = 0 -- resetta il contatore di movimento casuale
        return -- esce dalla funzione per aggiornare l'angolo casuale
    end
    random_movement_step_counter = random_movement_step_counter + 1
end

-- funzione per controllare gli attuatori
function actuator()
    -- se è in modalità di movimento casuale, esegue il movimento casuale
    if random_movement_mode then
        random_movement()
    else
        local wall_following_active = wall_following_vector.length > 0
        local light_detected = math.abs(light_angle) > LIGHT_THRESHOLD
		
		-- se ci sono ostacoli vengono evitati 
        if proximity_avoidance_angle ~= 0 then
            local avoidance_factor = math.min(proximity_resultant_length / PROXIMITY_THRESHOLD, 1)
            local left_speed = 10 * (1 + 2 * avoidance_factor * proximity_avoidance_angle / math.pi)
            local right_speed = 10 * (1 - 2 * avoidance_factor * proximity_avoidance_angle / math.pi)
            robot.wheels.set_velocity(left_speed, right_speed)

        -- se c'è un muro e viene rilevata luce si cerca un bilanciamento tra i due comportamenti 
        elseif wall_following_active and light_detected then
            -- calcola la velocità basata sull'angolo di wall-following
            local wall_following_speed = 10 * (1 - wall_following_vector.angle)
            local left_speed = wall_following_speed
            local right_speed = wall_following_speed

            -- aggiunge il movimento verso la luce
            left_speed = left_speed + 5 * (1 - light_angle)
            right_speed = right_speed + 5 * (1 + light_angle)

            robot.wheels.set_velocity(left_speed, right_speed)

        -- se è stato rilevato un muro 
        elseif wall_following_active then
            local left_speed = 10 * (1 - wall_following_vector.angle)
            local right_speed = 10 * (1 + wall_following_vector.angle)
            robot.wheels.set_velocity(left_speed, right_speed)

        -- muove verso la luce
        elseif light_detected then
            local left_speed = 10 * (1 - light_angle)
            local right_speed = 10 * (1 + light_angle)
            robot.wheels.set_velocity(left_speed, right_speed)

        -- se non ci sono informazioni significative, va dritto 
        else
            robot.wheels.set_velocity(10, 10)
        end
    end
end


-- funzione main per eseguire i comportamenti in sequenza
function main_controller()
    phototaxis()         -- esegue il comportamento di fototassi
    wall_following() 	 -- esegue il comportamento di wall-following
    compute_proximity()  -- esegue il comportamento per evitare gli ostacoli frontali
    actuator()           -- esegue il comportamento dell'attuatore
end


function init()

end


function step()
    main_controller()    -- chiama il main controller ad ogni passo
end

function reset()
    step_counter = 0
    random_movement_mode = false
    random_movement_step_counter = 0
    proximity_avoidance_angle = 0
    proximity_resultant_length = 0
    wall_following_vector = {length = 0, angle = 0}
end

function destroy()
  x = robot.positioning.position.x
  y = robot.positioning.position.y
  d = math.sqrt((x-1.5)^2 + y^2)
  print('f_distance ' .. d)
end
