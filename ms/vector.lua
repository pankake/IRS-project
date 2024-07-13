local vector = {}

-- Summing two 2D vectors in cartesian coordinates
function vector.vec2_sum(v1, v2)
	local v3 = {x = 0 , y = 0}	
	v3.x = v1.x + v2.x
	v3.y = v1.y + v2.y
	return v3	
end

-- From polar to cartesian coordinates
function vector.polar_to_cart(v)
	if v.length == nil or v.angle == nil then
		log("polar_to_cart: Invalid vector with length=" .. tostring(v.length) .. " and angle=" .. tostring(v.angle))
		return {x = 0, y = 0}
	end
	local z = {x = v.length * math.cos(v.angle) , y = v.length * math.sin(v.angle)}
	return z
end

-- Getting the angle of a 2D vector
function vector.vec2_angle(v)
	return math.atan2(v.y, v.x)
end

-- Getting the length of a 2D vector
function vector.vec2_length(v)
	return math.sqrt(math.pow(v.x,2) + math.pow(v.y,2))
end

-- From cartesian to polar coordinates
function vector.cart_to_polar(v)
	local z = {length = vector.vec2_length(v) , angle = vector.vec2_angle(v)}
	return z
end

-- Setting a 2D vector from length and angle
function vector.vec2_new_polar(length, angle)
	if length == nil or angle == nil then
		log("vec2_new_polar: Invalid parameters with length=" .. tostring(length) .. " and angle=" .. tostring(angle))
		return {x = 0, y = 0}
	end
	local vec2 = {
		x = length * math.cos(angle) ,
		y = length * math.sin(angle)
	}
	return vec2
end

-- Summing two 2D vectors in polar coordinates
function vector.vec2_polar_sum(v1, v2)
	local w1 = vector.polar_to_cart(v1)
	local w2 = vector.polar_to_cart(v2)
	local w3 = vector.vec2_sum(w1,w2)
	local v3 = vector.cart_to_polar(w3)	
	return v3	
end

return vector
