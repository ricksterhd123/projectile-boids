local boxStart = Vector3(0, 0, 100)
local boxWidth, boxLength, boxHeight = 200, 200, 200

local numBoids = 20
local visualRange = 75
local startingVelocity = 2
local maxVelocity = 5
local boids = {}

local _r = math.random


function init()
    for i = 1, numBoids do
        math.randomseed(getTickCount())
        local pos = Vector3(_r(-boxWidth, boxWidth), _r(-boxLength, boxLength), boxStart.z) + boxStart
        iprint("position: ", pos)
        
        local projectile = createProjectile(localPlayer, 20, pos.x, pos.y, pos.z)
        local delta = Vector3(getElementVelocity(projectile)):getNormalized() * startingVelocity
        setElementVelocity(projectile, delta.x, delta.y, delta.z)

        iprint("velocity: ", delta)

        table.insert(boids, {
            pos = pos,
            delta = delta,
            element = projectile
        })
    end
end

function distance(boid1, boid2)
    return (boid1.pos - boid2.pos):getLength()
end

function keepWithinBounds(boid)
    local margin = 50
    local turnFactor = 1

    if boid.pos.x < boxStart.x + margin then
        boid.delta.x = boid.delta.x + turnFactor
    end

    if boid.pos.x > boxStart.x + boxWidth - margin then
        boid.delta.x = boid.delta.x - turnFactor
    end

    if boid.pos.y < boxStart.y + margin then
        boid.delta.y = boid.delta.y + turnFactor
    end

    if boid.pos.y > boxStart.y + boxLength - margin then
        boid.delta.y = boid.delta.y - turnFactor
    end

    if boid.pos.z < boxStart.z + margin then
        boid.delta.z = boid.delta.z + turnFactor
    end

    if boid.pos.z > boxStart.z + boxHeight - margin then
        boid.delta.z = boid.delta.z - turnFactor
    end
end

function flyTowardsCenter(boid)
    local centeringFactor = 0.5 -- adjust velocity by this %

    local centerX = 0
    local centerY = 0
    local centerZ = 0
    local numNeighbors = 0

    -- Calculate center of mass if we find any close neighbours

    for i, otherBoid in ipairs(boids) do
        if distance(boid, otherBoid) < visualRange then
            centerX = centerX + otherBoid.pos.x
            centerY = centerY + otherBoid.pos.y
            centerZ = centerZ + otherBoid.pos.z
            numNeighbors = numNeighbors + 1
        end
    end

    if numNeighbors > 0 then
        centerX = centerX / numNeighbors
        centerY = centerY / numNeighbors
        centerZ = centerZ / numNeighbors

        local dx = centerX - boid.pos.x
        local dy = centerY - boid.pos.y
        local dz = centerZ - boid.pos.z

        -- push delta slightly towards center of mass of all nearby neighbours
        boid.delta.x = boid.delta.x + dx * centeringFactor
        boid.delta.y = boid.delta.y + dy * centeringFactor
        boid.delta.z = boid.delta.z + dz * centeringFactor
    end
end

function avoidOthers(boid)
    local minDistance = 10
    local avoidFactor = 1

    local moveX = 0
    local moveY = 0
    local moveZ = 0

    for i, otherBoid in ipairs(boids) do
        if distance(boid, otherBoid) < minDistance then
            moveX = moveX + boid.pos.x - otherBoid.pos.x
            moveY = moveY + boid.pos.y - otherBoid.pos.y
            moveZ = moveZ + boid.pos.z - otherBoid.pos.z
        end
    end

    boid.delta.x = boid.delta.x + moveX * avoidFactor
    boid.delta.y = boid.delta.y + moveY * avoidFactor
    boid.delta.z = boid.delta.z + moveZ * avoidFactor
end

function matchVelocity(boid)
    local matchingFactor = 0.5

    local avgDX = 0
    local avgDY = 0
    local avgDZ = 0
    local numNeighbors = 0

    for i, otherBoid in ipairs(boids) do
        if distance(boid, otherBoid) < visualRange then
            avgDX = avgDX + otherBoid.delta.x
            avgDY = avgDY + otherBoid.delta.y
            avgDZ = avgDZ + otherBoid.delta.z
            numNeighbors = numNeighbors + 1
        end
    end

    if numNeighbors > 0 then
        avgDX = avgDX / numNeighbors
        avgDY = avgDY / numNeighbors
        avgDZ = avgDZ / numNeighbors

        boid.delta.x = boid.delta.x + (avgDX - boid.delta.x) * matchingFactor
        boid.delta.y = boid.delta.y + (avgDY - boid.delta.y) * matchingFactor
        boid.delta.z = boid.delta.z + (avgDZ - boid.delta.z) * matchingFactor
    end
end

function limitSpeed(boid)
    local speedLimit = maxVelocity
    local speed = math.sqrt(boid.delta.x ^ 2, boid.delta.y ^ 2, boid.delta.z ^ 2)

    if speed > speedLimit then
        boid.delta.x = (boid.delta.x / speed) * speedLimit
        boid.delta.y = (boid.delta.y / speed) * speedLimit
        boid.delta.z = (boid.delta.z / speed) * speedLimit
    end
end

function setProjectileMatrix(p, forward)
    forward = -forward:getNormalized()
    forward = Vector3(forward:getX(), forward:getY(), - forward:getZ())
    local up = Vector3(0, 0, 1)
    local left = forward:cross(up)

    local ux, uy, uz = left:getX(), left:getY(), left:getZ()
    local vx, vy, vz = forward:getX(), forward:getY(), forward:getZ()
    local wx, wy, wz = up:getX(), up:getY(), up:getZ()
    local x, y, z = getElementPosition(p)

    setElementMatrix(p, {{ux, uy, uz, 0}, {vx, vy, vz, 0}, {wx, wy, wz, 0}, {x, y, z, 1}})
    return true
end


local FPS = 30
local lastTick = 0

function animationLoop(dt)
    local currentTick = getTickCount()
    for i, boid in ipairs(boids) do
        flyTowardsCenter(boid)            
        avoidOthers(boid)
        matchVelocity(boid)
        limitSpeed(boid)
        keepWithinBounds(boid)
        boid.pos = boid.pos + boid.delta * dt / 1000
        setElementPosition(boid.element, boid.pos)
        setProjectileMatrix(boid.element, boid.delta)
        setProjectileCounter(boid.element, 30000)
    end
end

function main()
    init()
    addEventHandler("onClientPreRender", root, animationLoop)
end

main()
