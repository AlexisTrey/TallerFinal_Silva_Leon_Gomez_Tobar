-- MarI/O by SethBling
-- Feel free to use this code, but please do not redistribute it.
-- Intended for use with the BizHawk emulator and Super Mario World or Super Mario Bros. ROM.
-- For SMW, make sure you have a save state named "DP1.state" at the beginning of a level,
-- and put a copy in both the Lua folder and the root directory of BizHawk.

-- ============================================================================
-- [SLTG] Taller Final Inteligencia Computacional (UPTC) - Punto 3
-- [SLTG] Grupo: Silva Leon Tovar Gomez.  Escenario A: Yoshi's Island 1 (Super Mario World)
-- [SLTG] Base: MarI/O (NEAT) de SethBling, SIN cambios en el algoritmo genetico.
-- [SLTG] Todas las lineas agregadas o modificadas por el grupo llevan la marca [SLTG].
-- [SLTG] Cambios sobre el original:
-- [SLTG]   1. Filename (savestate) y la meta del nivel salen de la tabla LN (abajo).
-- [SLTG]   2. Instrumentacion: CSV por generacion y por genoma, registro de eventos,
-- [SLTG]      capturas automaticas, pausa automatica en eventos y texto en pantalla
-- [SLTG]      con fecha, hora y usuario (evidencia con timestamp).
-- [SLTG]   3. Modo generalizacion (solo uso en el escenario A).
-- ============================================================================
LN = {}                                   -- [SLTG] configuracion del escenario
LN.escenario   = "A"
LN.nombreNivel = "Yoshi's Island 1"
LN.estado      = "YI1.state"            -- savestate al inicio del nivel (carpeta de EmuHawk)
LN.carpeta     = "resultados_escenarioA"   -- donde se guardan CSV y capturas
-- Posicion X (RAM 0x94) a partir de la cual se considera el nivel COMPLETADO.
-- 99999 = se detecta sola: la primera vez que un individuo cruza la meta, el
-- juego activa su temporizador de fin de nivel (RAM 0x1493) y el script fija
-- LN.metaX = X de Mario en ese instante - 1. Queda en eventos.csv (META_DETECTADA)
-- y se recupera al reanudar. Si ya se conoce el valor, puede escribirse aqui.
LN.metaX       = 99999
LN.metaMinimaX = 256                        -- descarta detecciones absurdas cerca del inicio
-- Reanudar: nombre del .pool desde el que se continua (vacio = entrenamiento nuevo).
-- Ejemplo: LN.poolReanudar = "backup.12.YI1.state.pool"
LN.poolReanudar = ""
LN.umbralFitness = 1000                     -- evento "fitness > 1000" de la guia
LN.generacionesEstancamiento = 50           -- evento "sin mejora en 50+ generaciones"
LN.pausarEnEventos = true                   -- pausa el emulador en cada evento
LN.capturasAutomaticas = true               -- guarda PNG en LN.carpeta
LN.mostrarPanel = true                      -- panel inferior con fecha/hora/usuario
LN.usuario = "USER"                         -- respaldo si no se puede leer el usuario de Windows
-- MODO GENERALIZACION (punto 3.2): ejecuta el mejor individuo entrenado en
-- este escenario (A) sobre el nivel del escenario B, SIN reentrenar.
LN.modo = "generalizacion"                  -- [SLTG] copia para la prueba de generalizacion (punto 3.2)
LN.poolGeneralizacion = "backup.51.YI1.state.pool" -- ultimo .pool de A (mejor individuo: fitness 4135.5)
LN.estadoGeneralizacion = "YI2.state"       -- savestate del nivel del escenario B
LN.metaXGeneralizacion = 4823               -- meta de B detectada en su entrenamiento (X = 4824)
LN.carpetaGeneralizacion = "resultados_generalizacion"
-- ============================================================================


if gameinfo.getromname() == "Super Mario World (USA)" then
	Filename = LN.estado -- [SLTG] original: Filename = "DP1.state"
	ButtonNames = {
		"A",
		"B",
		"X",
		"Y",
		"Up",
		"Down",
		"Left",
		"Right",
	}
elseif gameinfo.getromname() == "Super Mario Bros." then
	Filename = "SMB1-1.state"
	ButtonNames = {
		"A",
		"B",
		"Up",
		"Down",
		"Left",
		"Right",
	}
end

BoxRadius = 6
InputSize = (BoxRadius*2+1)*(BoxRadius*2+1)

Inputs = InputSize+1
Outputs = #ButtonNames

Population = 300
DeltaDisjoint = 2.0
DeltaWeights = 0.4
DeltaThreshold = 1.0

StaleSpecies = 15

MutateConnectionsChance = 0.25
PerturbChance = 0.90
CrossoverChance = 0.75
LinkMutationChance = 2.0
NodeMutationChance = 0.50
BiasMutationChance = 0.40
StepSize = 0.1
DisableMutationChance = 0.4
EnableMutationChance = 0.2

TimeoutConstant = 20

MaxNodes = 1000000

function getPositions()
	if gameinfo.getromname() == "Super Mario World (USA)" then
		marioX = memory.read_s16_le(0x94)
		marioY = memory.read_s16_le(0x96)
		
		local layer1x = memory.read_s16_le(0x1A);
		local layer1y = memory.read_s16_le(0x1C);
		
		screenX = marioX-layer1x
		screenY = marioY-layer1y
	elseif gameinfo.getromname() == "Super Mario Bros." then
		marioX = memory.readbyte(0x6D) * 0x100 + memory.readbyte(0x86)
		marioY = memory.readbyte(0x03B8)+16
	
		screenX = memory.readbyte(0x03AD)
		screenY = memory.readbyte(0x03B8)
	end
end

function getTile(dx, dy)
	if gameinfo.getromname() == "Super Mario World (USA)" then
		x = math.floor((marioX+dx+8)/16)
		y = math.floor((marioY+dy)/16)
		
		return memory.readbyte(0x1C800 + math.floor(x/0x10)*0x1B0 + y*0x10 + x%0x10)
	elseif gameinfo.getromname() == "Super Mario Bros." then
		local x = marioX + dx + 8
		local y = marioY + dy - 16
		local page = math.floor(x/256)%2

		local subx = math.floor((x%256)/16)
		local suby = math.floor((y - 32)/16)
		local addr = 0x500 + page*13*16+suby*16+subx
		
		if suby >= 13 or suby < 0 then
			return 0
		end
		
		if memory.readbyte(addr) ~= 0 then
			return 1
		else
			return 0
		end
	end
end

function getSprites()
	if gameinfo.getromname() == "Super Mario World (USA)" then
		local sprites = {}
		for slot=0,11 do
			local status = memory.readbyte(0x14C8+slot)
			if status ~= 0 then
				spritex = memory.readbyte(0xE4+slot) + memory.readbyte(0x14E0+slot)*256
				spritey = memory.readbyte(0xD8+slot) + memory.readbyte(0x14D4+slot)*256
				sprites[#sprites+1] = {["x"]=spritex, ["y"]=spritey}
			end
		end		
		
		return sprites
	elseif gameinfo.getromname() == "Super Mario Bros." then
		local sprites = {}
		for slot=0,4 do
			local enemy = memory.readbyte(0xF+slot)
			if enemy ~= 0 then
				local ex = memory.readbyte(0x6E + slot)*0x100 + memory.readbyte(0x87+slot)
				local ey = memory.readbyte(0xCF + slot)+24
				sprites[#sprites+1] = {["x"]=ex,["y"]=ey}
			end
		end
		
		return sprites
	end
end

function getExtendedSprites()
	if gameinfo.getromname() == "Super Mario World (USA)" then
		local extended = {}
		for slot=0,11 do
			local number = memory.readbyte(0x170B+slot)
			if number ~= 0 then
				spritex = memory.readbyte(0x171F+slot) + memory.readbyte(0x1733+slot)*256
				spritey = memory.readbyte(0x1715+slot) + memory.readbyte(0x1729+slot)*256
				extended[#extended+1] = {["x"]=spritex, ["y"]=spritey}
			end
		end		
		
		return extended
	elseif gameinfo.getromname() == "Super Mario Bros." then
		return {}
	end
end

function getInputs()
	getPositions()
	
	sprites = getSprites()
	extended = getExtendedSprites()
	
	local inputs = {}
	
	for dy=-BoxRadius*16,BoxRadius*16,16 do
		for dx=-BoxRadius*16,BoxRadius*16,16 do
			inputs[#inputs+1] = 0
			
			tile = getTile(dx, dy)
			if tile == 1 and marioY+dy < 0x1B0 then
				inputs[#inputs] = 1
			end
			
			for i = 1,#sprites do
				distx = math.abs(sprites[i]["x"] - (marioX+dx))
				disty = math.abs(sprites[i]["y"] - (marioY+dy))
				if distx <= 8 and disty <= 8 then
					inputs[#inputs] = -1
				end
			end

			for i = 1,#extended do
				distx = math.abs(extended[i]["x"] - (marioX+dx))
				disty = math.abs(extended[i]["y"] - (marioY+dy))
				if distx < 8 and disty < 8 then
					inputs[#inputs] = -1
				end
			end
		end
	end
	
	--mariovx = memory.read_s8(0x7B)
	--mariovy = memory.read_s8(0x7D)
	
	return inputs
end

function sigmoid(x)
	return 2/(1+math.exp(-4.9*x))-1
end

function newInnovation()
	pool.innovation = pool.innovation + 1
	return pool.innovation
end

function newPool()
	local pool = {}
	pool.species = {}
	pool.generation = 0
	pool.innovation = Outputs
	pool.currentSpecies = 1
	pool.currentGenome = 1
	pool.currentFrame = 0
	pool.maxFitness = 0
	
	return pool
end

function newSpecies()
	local species = {}
	species.topFitness = 0
	species.staleness = 0
	species.genomes = {}
	species.averageFitness = 0
	
	return species
end

function newGenome()
	local genome = {}
	genome.genes = {}
	genome.fitness = 0
	genome.adjustedFitness = 0
	genome.network = {}
	genome.maxneuron = 0
	genome.globalRank = 0
	genome.mutationRates = {}
	genome.mutationRates["connections"] = MutateConnectionsChance
	genome.mutationRates["link"] = LinkMutationChance
	genome.mutationRates["bias"] = BiasMutationChance
	genome.mutationRates["node"] = NodeMutationChance
	genome.mutationRates["enable"] = EnableMutationChance
	genome.mutationRates["disable"] = DisableMutationChance
	genome.mutationRates["step"] = StepSize
	
	return genome
end

function copyGenome(genome)
	local genome2 = newGenome()
	for g=1,#genome.genes do
		table.insert(genome2.genes, copyGene(genome.genes[g]))
	end
	genome2.maxneuron = genome.maxneuron
	genome2.mutationRates["connections"] = genome.mutationRates["connections"]
	genome2.mutationRates["link"] = genome.mutationRates["link"]
	genome2.mutationRates["bias"] = genome.mutationRates["bias"]
	genome2.mutationRates["node"] = genome.mutationRates["node"]
	genome2.mutationRates["enable"] = genome.mutationRates["enable"]
	genome2.mutationRates["disable"] = genome.mutationRates["disable"]
	
	return genome2
end

function basicGenome()
	local genome = newGenome()
	local innovation = 1

	genome.maxneuron = Inputs
	mutate(genome)
	
	return genome
end

function newGene()
	local gene = {}
	gene.into = 0
	gene.out = 0
	gene.weight = 0.0
	gene.enabled = true
	gene.innovation = 0
	
	return gene
end

function copyGene(gene)
	local gene2 = newGene()
	gene2.into = gene.into
	gene2.out = gene.out
	gene2.weight = gene.weight
	gene2.enabled = gene.enabled
	gene2.innovation = gene.innovation
	
	return gene2
end

function newNeuron()
	local neuron = {}
	neuron.incoming = {}
	neuron.value = 0.0
	
	return neuron
end

function generateNetwork(genome)
	local network = {}
	network.neurons = {}
	
	for i=1,Inputs do
		network.neurons[i] = newNeuron()
	end
	
	for o=1,Outputs do
		network.neurons[MaxNodes+o] = newNeuron()
	end
	
	table.sort(genome.genes, function (a,b)
		return (a.out < b.out)
	end)
	for i=1,#genome.genes do
		local gene = genome.genes[i]
		if gene.enabled then
			if network.neurons[gene.out] == nil then
				network.neurons[gene.out] = newNeuron()
			end
			local neuron = network.neurons[gene.out]
			table.insert(neuron.incoming, gene)
			if network.neurons[gene.into] == nil then
				network.neurons[gene.into] = newNeuron()
			end
		end
	end
	
	genome.network = network
end

function evaluateNetwork(network, inputs)
	table.insert(inputs, 1)
	if #inputs ~= Inputs then
		console.writeline("Incorrect number of neural network inputs.")
		return {}
	end
	
	for i=1,Inputs do
		network.neurons[i].value = inputs[i]
	end
	
	for _,neuron in pairs(network.neurons) do
		local sum = 0
		for j = 1,#neuron.incoming do
			local incoming = neuron.incoming[j]
			local other = network.neurons[incoming.into]
			sum = sum + incoming.weight * other.value
		end
		
		if #neuron.incoming > 0 then
			neuron.value = sigmoid(sum)
		end
	end
	
	local outputs = {}
	for o=1,Outputs do
		local button = "P1 " .. ButtonNames[o]
		if network.neurons[MaxNodes+o].value > 0 then
			outputs[button] = true
		else
			outputs[button] = false
		end
	end
	
	return outputs
end

function crossover(g1, g2)
	-- Make sure g1 is the higher fitness genome
	if g2.fitness > g1.fitness then
		tempg = g1
		g1 = g2
		g2 = tempg
	end

	local child = newGenome()
	
	local innovations2 = {}
	for i=1,#g2.genes do
		local gene = g2.genes[i]
		innovations2[gene.innovation] = gene
	end
	
	for i=1,#g1.genes do
		local gene1 = g1.genes[i]
		local gene2 = innovations2[gene1.innovation]
		if gene2 ~= nil and math.random(2) == 1 and gene2.enabled then
			table.insert(child.genes, copyGene(gene2))
		else
			table.insert(child.genes, copyGene(gene1))
		end
	end
	
	child.maxneuron = math.max(g1.maxneuron,g2.maxneuron)
	
	for mutation,rate in pairs(g1.mutationRates) do
		child.mutationRates[mutation] = rate
	end
	
	return child
end

function randomNeuron(genes, nonInput)
	local neurons = {}
	if not nonInput then
		for i=1,Inputs do
			neurons[i] = true
		end
	end
	for o=1,Outputs do
		neurons[MaxNodes+o] = true
	end
	for i=1,#genes do
		if (not nonInput) or genes[i].into > Inputs then
			neurons[genes[i].into] = true
		end
		if (not nonInput) or genes[i].out > Inputs then
			neurons[genes[i].out] = true
		end
	end

	local count = 0
	for _,_ in pairs(neurons) do
		count = count + 1
	end
	local n = math.random(1, count)
	
	for k,v in pairs(neurons) do
		n = n-1
		if n == 0 then
			return k
		end
	end
	
	return 0
end

function containsLink(genes, link)
	for i=1,#genes do
		local gene = genes[i]
		if gene.into == link.into and gene.out == link.out then
			return true
		end
	end
end

function pointMutate(genome)
	local step = genome.mutationRates["step"]
	
	for i=1,#genome.genes do
		local gene = genome.genes[i]
		if math.random() < PerturbChance then
			gene.weight = gene.weight + math.random() * step*2 - step
		else
			gene.weight = math.random()*4-2
		end
	end
end

function linkMutate(genome, forceBias)
	local neuron1 = randomNeuron(genome.genes, false)
	local neuron2 = randomNeuron(genome.genes, true)
	 
	local newLink = newGene()
	if neuron1 <= Inputs and neuron2 <= Inputs then
		--Both input nodes
		return
	end
	if neuron2 <= Inputs then
		-- Swap output and input
		local temp = neuron1
		neuron1 = neuron2
		neuron2 = temp
	end

	newLink.into = neuron1
	newLink.out = neuron2
	if forceBias then
		newLink.into = Inputs
	end
	
	if containsLink(genome.genes, newLink) then
		return
	end
	newLink.innovation = newInnovation()
	newLink.weight = math.random()*4-2
	
	table.insert(genome.genes, newLink)
end

function nodeMutate(genome)
	if #genome.genes == 0 then
		return
	end

	genome.maxneuron = genome.maxneuron + 1

	local gene = genome.genes[math.random(1,#genome.genes)]
	if not gene.enabled then
		return
	end
	gene.enabled = false
	
	local gene1 = copyGene(gene)
	gene1.out = genome.maxneuron
	gene1.weight = 1.0
	gene1.innovation = newInnovation()
	gene1.enabled = true
	table.insert(genome.genes, gene1)
	
	local gene2 = copyGene(gene)
	gene2.into = genome.maxneuron
	gene2.innovation = newInnovation()
	gene2.enabled = true
	table.insert(genome.genes, gene2)
end

function enableDisableMutate(genome, enable)
	local candidates = {}
	for _,gene in pairs(genome.genes) do
		if gene.enabled == not enable then
			table.insert(candidates, gene)
		end
	end
	
	if #candidates == 0 then
		return
	end
	
	local gene = candidates[math.random(1,#candidates)]
	gene.enabled = not gene.enabled
end

function mutate(genome)
	for mutation,rate in pairs(genome.mutationRates) do
		if math.random(1,2) == 1 then
			genome.mutationRates[mutation] = 0.95*rate
		else
			genome.mutationRates[mutation] = 1.05263*rate
		end
	end

	if math.random() < genome.mutationRates["connections"] then
		pointMutate(genome)
	end
	
	local p = genome.mutationRates["link"]
	while p > 0 do
		if math.random() < p then
			linkMutate(genome, false)
		end
		p = p - 1
	end

	p = genome.mutationRates["bias"]
	while p > 0 do
		if math.random() < p then
			linkMutate(genome, true)
		end
		p = p - 1
	end
	
	p = genome.mutationRates["node"]
	while p > 0 do
		if math.random() < p then
			nodeMutate(genome)
		end
		p = p - 1
	end
	
	p = genome.mutationRates["enable"]
	while p > 0 do
		if math.random() < p then
			enableDisableMutate(genome, true)
		end
		p = p - 1
	end

	p = genome.mutationRates["disable"]
	while p > 0 do
		if math.random() < p then
			enableDisableMutate(genome, false)
		end
		p = p - 1
	end
end

function disjoint(genes1, genes2)
	local i1 = {}
	for i = 1,#genes1 do
		local gene = genes1[i]
		i1[gene.innovation] = true
	end

	local i2 = {}
	for i = 1,#genes2 do
		local gene = genes2[i]
		i2[gene.innovation] = true
	end
	
	local disjointGenes = 0
	for i = 1,#genes1 do
		local gene = genes1[i]
		if not i2[gene.innovation] then
			disjointGenes = disjointGenes+1
		end
	end
	
	for i = 1,#genes2 do
		local gene = genes2[i]
		if not i1[gene.innovation] then
			disjointGenes = disjointGenes+1
		end
	end
	
	local n = math.max(#genes1, #genes2)
	
	return disjointGenes / n
end

function weights(genes1, genes2)
	local i2 = {}
	for i = 1,#genes2 do
		local gene = genes2[i]
		i2[gene.innovation] = gene
	end

	local sum = 0
	local coincident = 0
	for i = 1,#genes1 do
		local gene = genes1[i]
		if i2[gene.innovation] ~= nil then
			local gene2 = i2[gene.innovation]
			sum = sum + math.abs(gene.weight - gene2.weight)
			coincident = coincident + 1
		end
	end
	
	return sum / coincident
end
	
function sameSpecies(genome1, genome2)
	local dd = DeltaDisjoint*disjoint(genome1.genes, genome2.genes)
	local dw = DeltaWeights*weights(genome1.genes, genome2.genes) 
	return dd + dw < DeltaThreshold
end

function rankGlobally()
	local global = {}
	for s = 1,#pool.species do
		local species = pool.species[s]
		for g = 1,#species.genomes do
			table.insert(global, species.genomes[g])
		end
	end
	table.sort(global, function (a,b)
		return (a.fitness < b.fitness)
	end)
	
	for g=1,#global do
		global[g].globalRank = g
	end
end

function calculateAverageFitness(species)
	local total = 0
	
	for g=1,#species.genomes do
		local genome = species.genomes[g]
		total = total + genome.globalRank
	end
	
	species.averageFitness = total / #species.genomes
end

function totalAverageFitness()
	local total = 0
	for s = 1,#pool.species do
		local species = pool.species[s]
		total = total + species.averageFitness
	end

	return total
end

function cullSpecies(cutToOne)
	for s = 1,#pool.species do
		local species = pool.species[s]
		
		table.sort(species.genomes, function (a,b)
			return (a.fitness > b.fitness)
		end)
		
		local remaining = math.ceil(#species.genomes/2)
		if cutToOne then
			remaining = 1
		end
		while #species.genomes > remaining do
			table.remove(species.genomes)
		end
	end
end

function breedChild(species)
	local child = {}
	if math.random() < CrossoverChance then
		g1 = species.genomes[math.random(1, #species.genomes)]
		g2 = species.genomes[math.random(1, #species.genomes)]
		child = crossover(g1, g2)
	else
		g = species.genomes[math.random(1, #species.genomes)]
		child = copyGenome(g)
	end
	
	mutate(child)
	
	return child
end

function removeStaleSpecies()
	local survived = {}

	for s = 1,#pool.species do
		local species = pool.species[s]
		
		table.sort(species.genomes, function (a,b)
			return (a.fitness > b.fitness)
		end)
		
		if species.genomes[1].fitness > species.topFitness then
			species.topFitness = species.genomes[1].fitness
			species.staleness = 0
		else
			species.staleness = species.staleness + 1
		end
		if species.staleness < StaleSpecies or species.topFitness >= pool.maxFitness then
			table.insert(survived, species)
		end
	end

	pool.species = survived
end

function removeWeakSpecies()
	local survived = {}

	local sum = totalAverageFitness()
	for s = 1,#pool.species do
		local species = pool.species[s]
		breed = math.floor(species.averageFitness / sum * Population)
		if breed >= 1 then
			table.insert(survived, species)
		end
	end

	pool.species = survived
end


function addToSpecies(child)
	local foundSpecies = false
	for s=1,#pool.species do
		local species = pool.species[s]
		if not foundSpecies and sameSpecies(child, species.genomes[1]) then
			table.insert(species.genomes, child)
			foundSpecies = true
		end
	end
	
	if not foundSpecies then
		local childSpecies = newSpecies()
		table.insert(childSpecies.genomes, child)
		table.insert(pool.species, childSpecies)
	end
end

function newGeneration()
	ln_registrarGeneracion() -- [SLTG] estadisticas de la generacion completa, antes de la seleccion
	cullSpecies(false) -- Cull the bottom half of each species
	rankGlobally()
	removeStaleSpecies()
	rankGlobally()
	for s = 1,#pool.species do
		local species = pool.species[s]
		calculateAverageFitness(species)
	end
	removeWeakSpecies()
	local sum = totalAverageFitness()
	local children = {}
	for s = 1,#pool.species do
		local species = pool.species[s]
		breed = math.floor(species.averageFitness / sum * Population) - 1
		for i=1,breed do
			table.insert(children, breedChild(species))
		end
	end
	cullSpecies(true) -- Cull all but the top member of each species
	while #children + #pool.species < Population do
		local species = pool.species[math.random(1, #pool.species)]
		table.insert(children, breedChild(species))
	end
	for c=1,#children do
		local child = children[c]
		addToSpecies(child)
	end
	
	pool.generation = pool.generation + 1
	
	writeFile("backup." .. pool.generation .. "." .. forms.gettext(saveLoadFile))
end
	
function initializePool()
	pool = newPool()

	for i=1,Population do
		basic = basicGenome()
		addToSpecies(basic)
	end

	initializeRun()
end

function clearJoypad()
	controller = {}
	for b = 1,#ButtonNames do
		controller["P1 " .. ButtonNames[b]] = false
	end
	joypad.set(controller)
end

function initializeRun()
	savestate.load(Filename);
	rightmost = 0
	pool.currentFrame = 0
	timeout = TimeoutConstant
	clearJoypad()
	
	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]
	generateNetwork(genome)
	evaluateCurrent()
end

function evaluateCurrent()
	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]

	inputs = getInputs()
	controller = evaluateNetwork(genome.network, inputs)
	
	if controller["P1 Left"] and controller["P1 Right"] then
		controller["P1 Left"] = false
		controller["P1 Right"] = false
	end
	if controller["P1 Up"] and controller["P1 Down"] then
		controller["P1 Up"] = false
		controller["P1 Down"] = false
	end

	joypad.set(controller)
end

if pool == nil then
	initializePool()
end


function nextGenome()
	pool.currentGenome = pool.currentGenome + 1
	if pool.currentGenome > #pool.species[pool.currentSpecies].genomes then
		pool.currentGenome = 1
		pool.currentSpecies = pool.currentSpecies+1
		if pool.currentSpecies > #pool.species then
			newGeneration()
			pool.currentSpecies = 1
		end
	end
end

function fitnessAlreadyMeasured()
	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]
	
	return genome.fitness ~= 0
end

function displayGenome(genome)
	local network = genome.network
	local cells = {}
	local i = 1
	local cell = {}
	for dy=-BoxRadius,BoxRadius do
		for dx=-BoxRadius,BoxRadius do
			cell = {}
			cell.x = 50+5*dx
			cell.y = 70+5*dy
			cell.value = network.neurons[i].value
			cells[i] = cell
			i = i + 1
		end
	end
	local biasCell = {}
	biasCell.x = 80
	biasCell.y = 110
	biasCell.value = network.neurons[Inputs].value
	cells[Inputs] = biasCell
	
	for o = 1,Outputs do
		cell = {}
		cell.x = 220
		cell.y = 30 + 8 * o
		cell.value = network.neurons[MaxNodes + o].value
		cells[MaxNodes+o] = cell
		local color
		if cell.value > 0 then
			color = 0xFF0000FF
		else
			color = 0xFF000000
		end
		gui.drawText(223, 24+8*o, ButtonNames[o], color, 9)
	end
	
	for n,neuron in pairs(network.neurons) do
		cell = {}
		if n > Inputs and n <= MaxNodes then
			cell.x = 140
			cell.y = 40
			cell.value = neuron.value
			cells[n] = cell
		end
	end
	
	for n=1,4 do
		for _,gene in pairs(genome.genes) do
			if gene.enabled then
				local c1 = cells[gene.into]
				local c2 = cells[gene.out]
				if gene.into > Inputs and gene.into <= MaxNodes then
					c1.x = 0.75*c1.x + 0.25*c2.x
					if c1.x >= c2.x then
						c1.x = c1.x - 40
					end
					if c1.x < 90 then
						c1.x = 90
					end
					
					if c1.x > 220 then
						c1.x = 220
					end
					c1.y = 0.75*c1.y + 0.25*c2.y
					
				end
				if gene.out > Inputs and gene.out <= MaxNodes then
					c2.x = 0.25*c1.x + 0.75*c2.x
					if c1.x >= c2.x then
						c2.x = c2.x + 40
					end
					if c2.x < 90 then
						c2.x = 90
					end
					if c2.x > 220 then
						c2.x = 220
					end
					c2.y = 0.25*c1.y + 0.75*c2.y
				end
			end
		end
	end
	
	gui.drawBox(50-BoxRadius*5-3,70-BoxRadius*5-3,50+BoxRadius*5+2,70+BoxRadius*5+2,0xFF000000, 0x80808080)
	for n,cell in pairs(cells) do
		if n > Inputs or cell.value ~= 0 then
			local color = math.floor((cell.value+1)/2*256)
			if color > 255 then color = 255 end
			if color < 0 then color = 0 end
			local opacity = 0xFF000000
			if cell.value == 0 then
				opacity = 0x50000000
			end
			color = opacity + color*0x10000 + color*0x100 + color
			gui.drawBox(cell.x-2,cell.y-2,cell.x+2,cell.y+2,opacity,color)
		end
	end
	for _,gene in pairs(genome.genes) do
		if gene.enabled then
			local c1 = cells[gene.into]
			local c2 = cells[gene.out]
			local opacity = 0xA0000000
			if c1.value == 0 then
				opacity = 0x20000000
			end
			
			local color = 0x80-math.floor(math.abs(sigmoid(gene.weight))*0x80)
			if gene.weight > 0 then 
				color = opacity + 0x8000 + 0x10000*color
			else
				color = opacity + 0x800000 + 0x100*color
			end
			gui.drawLine(c1.x+1, c1.y, c2.x-3, c2.y, color)
		end
	end
	
	gui.drawBox(49,71,51,78,0x00000000,0x80FF0000)
	
	if forms.ischecked(showMutationRates) then
		local pos = 100
		for mutation,rate in pairs(genome.mutationRates) do
			gui.drawText(100, pos, mutation .. ": " .. rate, 0xFF000000, 10)
			pos = pos + 8
		end
	end
end

function writeFile(filename)
        local file = io.open(filename, "w")
	file:write(pool.generation .. "\n")
	file:write(pool.maxFitness .. "\n")
	file:write(#pool.species .. "\n")
        for n,species in pairs(pool.species) do
		file:write(species.topFitness .. "\n")
		file:write(species.staleness .. "\n")
		file:write(#species.genomes .. "\n")
		for m,genome in pairs(species.genomes) do
			file:write(genome.fitness .. "\n")
			file:write(genome.maxneuron .. "\n")
			for mutation,rate in pairs(genome.mutationRates) do
				file:write(mutation .. "\n")
				file:write(rate .. "\n")
			end
			file:write("done\n")
			
			file:write(#genome.genes .. "\n")
			for l,gene in pairs(genome.genes) do
				file:write(gene.into .. " ")
				file:write(gene.out .. " ")
				file:write(gene.weight .. " ")
				file:write(gene.innovation .. " ")
				if(gene.enabled) then
					file:write("1\n")
				else
					file:write("0\n")
				end
			end
		end
        end
        file:close()
end

function savePool()
	local filename = forms.gettext(saveLoadFile)
	writeFile(filename)
end

function loadFile(filename)
        local file = io.open(filename, "r")
	pool = newPool()
	pool.generation = file:read("*number")
	pool.maxFitness = file:read("*number")
	forms.settext(maxFitnessLabel, "Max Fitness: " .. math.floor(pool.maxFitness))
        local numSpecies = file:read("*number")
        for s=1,numSpecies do
		local species = newSpecies()
		table.insert(pool.species, species)
		species.topFitness = file:read("*number")
		species.staleness = file:read("*number")
		local numGenomes = file:read("*number")
		for g=1,numGenomes do
			local genome = newGenome()
			table.insert(species.genomes, genome)
			genome.fitness = file:read("*number")
			genome.maxneuron = file:read("*number")
			local line = file:read("*line")
			while line ~= "done" do
				genome.mutationRates[line] = file:read("*number")
				line = file:read("*line")
			end
			local numGenes = file:read("*number")
			for n=1,numGenes do
				local gene = newGene()
				table.insert(genome.genes, gene)
				local enabled
				gene.into, gene.out, gene.weight, gene.innovation, enabled = file:read("*number", "*number", "*number", "*number", "*number")
				if enabled == 0 then
					gene.enabled = false
				else
					gene.enabled = true
				end
				
			end
		end
	end
        file:close()
	
	while fitnessAlreadyMeasured() do
		nextGenome()
	end
	initializeRun()
	pool.currentFrame = pool.currentFrame + 1
end
 
function loadPool()
	local filename = forms.gettext(saveLoadFile)
	loadFile(filename)
end

function playTop()
	local maxfitness = 0
	local maxs, maxg
	for s,species in pairs(pool.species) do
		for g,genome in pairs(species.genomes) do
			if genome.fitness > maxfitness then
				maxfitness = genome.fitness
				maxs = s
				maxg = g
			end
		end
	end
	
	pool.currentSpecies = maxs
	pool.currentGenome = maxg
	pool.maxFitness = maxfitness
	forms.settext(maxFitnessLabel, "Max Fitness: " .. math.floor(pool.maxFitness))
	initializeRun()
	pool.currentFrame = pool.currentFrame + 1
	return
end

function onExit()
	forms.destroy(form)
end

-- ============================================================================
-- [SLTG] >>> INSTRUMENTACION DEL TALLER (Silva Leon Tovar Gomez) >>>
-- Esta seccion NO modifica el algoritmo NEAT (seleccion, cruce, mutacion,
-- especiacion ni formula de fitness). Solo observa el estado de la poblacion y:
--   * escribe generaciones.csv  (una fila por generacion: max, promedio, min,
--     especies, tasas de mutacion promedio, generaciones sin mejora, tiempo)
--   * escribe genomas.csv       (una fila por individuo evaluado)
--   * escribe eventos.csv       (gen. 1 terminada, nuevo record, fitness > 1000,
--     nivel completado, estancamiento, resultados de generalizacion)
--   * toma capturas PNG y pausa el emulador en los eventos que pide la guia
--   * dibuja un panel con fecha, hora y usuario de Windows (timestamp)
--   * detecta sola la posicion de la meta (RAM 0x1493, fin de nivel)
-- Todas las funciones empiezan por "ln_" para distinguirlas del codigo original.
-- ============================================================================

lnEstado = {
	tiempoAcum = 0,          -- segundos de entrenamiento efectivo (no cuenta pausas)
	ultimoT = os.time(),
	inicioGenT = 0,          -- tiempoAcum al empezar la generacion actual
	record = nil,            -- mejor fitness individual observado
	recordGen = 0,
	ultimoMaxHist = nil,     -- maximo historico al cerrar la generacion anterior
	gensSinMejora = 0,
	estancamientoAvisado = false,
	completosGen = 0,        -- individuos que completaron el nivel en la generacion
	ultimaGenMax = nil,
	ultimaGenProm = nil,
	eventos = {},            -- eventos unicos ya ocurridos
	mensaje = "Sin eventos todavia",
	usuario = "?",
	mejorS = nil, mejorG = nil, fitnessA = nil,
	intentosGeneralizacion = 0,
}

function ln_gen()
	-- El script cuenta desde 0; la guia habla de "generacion 1" para la inicial.
	return pool.generation + 1
end

function ln_fechaHora()
	return os.date("%Y-%m-%d %H:%M:%S")
end

function ln_num(x)
	return string.format("%.2f", x)
end

function ln_ruta(nombre)
	return LN.carpeta .. "/" .. nombre
end

function ln_existe(ruta)
	local f = io.open(ruta, "r")
	if f then
		f:close()
		return true
	end
	return false
end

function ln_append(nombre, linea, encabezado)
	local ruta = ln_ruta(nombre)
	local existia = ln_existe(ruta)
	local f = io.open(ruta, "a")
	if f == nil then
		console.writeline("[SLTG] No se pudo escribir " .. ruta .. " (verifique que la carpeta exista)")
		return
	end
	if not existia and encabezado ~= nil then
		f:write(encabezado .. "\n")
	end
	f:write(linea .. "\n")
	f:close()
end

function ln_split(linea)
	local campos = {}
	for campo in string.gmatch(linea .. ",", "([^,]*),") do
		campos[#campos + 1] = campo
	end
	return campos
end

function ln_captura(etiqueta)
	if not LN.capturasAutomaticas then
		return ""
	end
	lnEstado.numCaptura = (lnEstado.numCaptura or 0) + 1
	local nombre = string.format("%s_esc%s_gen%d_%s_%03d.png", etiqueta, LN.escenario, ln_gen(),
		os.date("%Y%m%d_%H%M%S"), lnEstado.numCaptura)
	local ok = pcall(client.screenshot, ln_ruta(nombre))
	if not ok then
		console.writeline("[SLTG] No se pudo guardar la captura " .. nombre)
		return ""
	end
	return nombre
end

function ln_pausar(mensaje)
	lnEstado.mensaje = mensaje
	console.writeline("[SLTG] " .. ln_fechaHora() .. " " .. mensaje)
	if LN.pausarEnEventos then
		console.writeline("[SLTG] Emulador PAUSADO. Tome la captura y reanude con Emulation > Pause (tecla Pause).")
		client.pause()
	end
end

-- Registra un evento en eventos.csv, toma captura y (opcional) pausa.
-- deGeneracion = true para eventos de toda la generacion (sin especie/genoma).
function ln_evento(tipo, fitness, detalle, pausar, deGeneracion)
	local captura = ln_captura(string.lower(tipo))
	local especie, genoma, x = pool.currentSpecies, pool.currentGenome, math.floor(rightmost or 0)
	if deGeneracion then
		especie, genoma, x = "-", "-", "-"
	end
	ln_append("eventos.csv",
		table.concat({ln_fechaHora(), tipo, ln_gen(), especie, genoma,
			ln_num(fitness), x, ln_num(lnEstado.tiempoAcum / 60), captura, detalle}, ","),
		"fecha_hora,evento,generacion,especie,genoma,fitness,rightmost,tiempo_entrenamiento_min,captura,detalle")
	lnEstado.eventos[tipo] = true
	if pausar then
		ln_pausar(tipo .. " g" .. ln_gen() .. " " .. string.format("%.1f", fitness))
	end
end

-- Se llama cuando un individuo termina su intento (ya tiene fitness asignado).
function ln_alEvaluarGenoma(genome, fitness)
	if LN.modo == "generalizacion" then
		ln_resultadoGeneralizacion(fitness)
		return
	end

	local completo = rightmost > LN.metaX
	if completo then
		lnEstado.completosGen = lnEstado.completosGen + 1
	end

	ln_append("genomas.csv",
		table.concat({ln_fechaHora(), ln_gen(), pool.currentSpecies, pool.currentGenome, ln_num(fitness),
			math.floor(rightmost), pool.currentFrame, completo and 1 or 0, ln_num(lnEstado.tiempoAcum / 60)}, ","),
		"fecha_hora,generacion,especie,genoma,fitness,rightmost,frames,completo_nivel,tiempo_entrenamiento_min")

	if lnEstado.record == nil or fitness > lnEstado.record then
		lnEstado.record = fitness
		lnEstado.recordGen = ln_gen()
		ln_evento("NUEVO_RECORD", fitness, "mejor individuo hasta ahora", false)
	end

	if fitness > LN.umbralFitness and not lnEstado.eventos["FITNESS_SUPERA_1000"] then
		ln_evento("FITNESS_SUPERA_1000", fitness, "primer individuo con fitness > " .. LN.umbralFitness, true)
	end

	if completo and not lnEstado.eventos["NIVEL_COMPLETADO"] then
		ln_evento("NIVEL_COMPLETADO", fitness, "rightmost " .. math.floor(rightmost) .. " > meta " .. LN.metaX, true)
	end
end

-- Se llama al inicio de newGeneration(): todos los individuos tienen fitness.
function ln_registrarGeneracion()
	if LN.modo == "generalizacion" then
		return
	end

	local n, suma, maxG, minG = 0, 0, nil, nil
	local claves = {"connections", "link", "bias", "node", "enable", "disable", "step"}
	local tasas = {}
	for _, k in ipairs(claves) do
		tasas[k] = 0
	end

	for _, species in pairs(pool.species) do
		for _, g in pairs(species.genomes) do
			n = n + 1
			suma = suma + g.fitness
			if maxG == nil or g.fitness > maxG then maxG = g.fitness end
			if minG == nil or g.fitness < minG then minG = g.fitness end
			for _, k in ipairs(claves) do
				tasas[k] = tasas[k] + (g.mutationRates[k] or 0)
			end
		end
	end
	if n == 0 then
		return
	end
	local prom = suma / n

	if lnEstado.ultimoMaxHist == nil or pool.maxFitness > lnEstado.ultimoMaxHist then
		lnEstado.gensSinMejora = 0
		lnEstado.estancamientoAvisado = false
	else
		lnEstado.gensSinMejora = lnEstado.gensSinMejora + 1
	end
	lnEstado.ultimoMaxHist = pool.maxFitness

	local tiempoGen = lnEstado.tiempoAcum - lnEstado.inicioGenT
	lnEstado.inicioGenT = lnEstado.tiempoAcum

	local fila = {ln_fechaHora(), ln_gen(), n, #pool.species, ln_num(maxG), ln_num(prom), ln_num(minG),
		ln_num(pool.maxFitness), lnEstado.gensSinMejora, lnEstado.completosGen}
	for _, k in ipairs(claves) do
		fila[#fila + 1] = string.format("%.4f", tasas[k] / n)
	end
	fila[#fila + 1] = string.format("%.3f", tiempoGen / 60)
	fila[#fila + 1] = string.format("%.3f", lnEstado.tiempoAcum / 60)

	ln_append("generaciones.csv", table.concat(fila, ","),
		"fecha_hora,generacion,poblacion,especies,fitness_max_gen,fitness_prom_gen,fitness_min_gen," ..
		"fitness_max_historico,gens_sin_mejora,completaron_nivel," ..
		"tasa_connections_prom,tasa_link_prom,tasa_bias_prom,tasa_node_prom,tasa_enable_prom," ..
		"tasa_disable_prom,step_prom,tiempo_gen_min,tiempo_acum_min")
	console.writeline(string.format("[SLTG] Generacion %d cerrada: max %.2f | promedio %.2f | especies %d | %.1f min",
		ln_gen(), maxG, prom, #pool.species, lnEstado.tiempoAcum / 60))

	lnEstado.ultimaGenMax = maxG
	lnEstado.ultimaGenProm = prom
	lnEstado.completosGen = 0

	if pool.generation == 0 and not lnEstado.eventos["FIN_GENERACION_1"] then
		ln_evento("FIN_GENERACION_1", maxG, "promedio " .. ln_num(prom), true, true)
	end

	if lnEstado.gensSinMejora >= LN.generacionesEstancamiento and not lnEstado.estancamientoAvisado then
		lnEstado.estancamientoAvisado = true
		ln_evento("ESTANCAMIENTO", pool.maxFitness, lnEstado.gensSinMejora .. " generaciones sin mejorar el maximo", true, true)
	end
end

-- Deteccion automatica de la meta (Super Mario World).
-- RAM 0x1493: temporizador de fin de nivel; el juego lo activa (distinto de 0)
--             cuando Mario cruza la meta del nivel.
-- RAM 0x71:   animacion de Mario; 9 = muerte (se descarta para evitar falsos positivos).
-- La primera vez que ocurre, LN.metaX = X de Mario - 1, de modo que la condicion
-- original "rightmost > LN.metaX" (bono +1000) se cumple para quien cruce la meta.
function ln_detectarMeta()
	if LN.metaX < 99999 then
		return
	end
	if memory.readbyte(0x1493) == 0 or memory.readbyte(0x71) == 9 then
		return
	end
	local x = memory.read_s16_le(0x94)
	if x < LN.metaMinimaX then
		return
	end
	LN.metaX = x - 1
	console.writeline("[SLTG] Meta detectada automaticamente en X = " .. x .. " (LN.metaX = " .. LN.metaX .. ")")
	ln_evento("META_DETECTADA", rightmost - pool.currentFrame / 2, "metaX=" .. LN.metaX, false)
end

-- Tiempo de entrenamiento y panel inferior; se llama una vez por frame.
function ln_cadaFrame()
	ln_detectarMeta()
	local ahora = os.time()
	local d = ahora - lnEstado.ultimoT
	-- Saltos mayores a 3 s se consideran pausas y no cuentan como entrenamiento.
	if d > 0 and d <= 3 and LN.modo ~= "generalizacion" then
		lnEstado.tiempoAcum = lnEstado.tiempoAcum + d
	end
	lnEstado.ultimoT = ahora

	if not LN.mostrarPanel then
		return
	end

	-- Pantalla SNES de 256 px: lineas cortas (~42 caracteres).
	local l1, l3
	if LN.modo == "generalizacion" then
		l1 = "SILVA LEON TOVAR GOMEZ  GENERALIZ. A -> " .. LN.estado
		l3 = string.format("Fit. en A %s  intentos en B %d",
			lnEstado.fitnessA and string.format("%.1f", lnEstado.fitnessA) or "?", lnEstado.intentosGeneralizacion)
	else
		l1 = "SILVA LEON TOVAR GOMEZ  Esc." .. LN.escenario .. " " .. LN.nombreNivel
		if LN.metaX >= 99999 then
			l1 = "SILVA LEON TOVAR GOMEZ  Esc." .. LN.escenario .. "  meta: auto"
		end
		l3 = string.format("G%d ant:max %s prom %s rec %s", ln_gen(),
			lnEstado.ultimaGenMax and string.format("%.1f", lnEstado.ultimaGenMax) or "-",
			lnEstado.ultimaGenProm and string.format("%.1f", lnEstado.ultimaGenProm) or "-",
			lnEstado.record and string.format("%.1f", lnEstado.record) or "-")
	end
	local l2 = string.format("%s %s t=%.1fmin", ln_fechaHora(), lnEstado.usuario, lnEstado.tiempoAcum / 60)
	local l4 = "Ev: " .. lnEstado.mensaje

	gui.drawBox(0, 185, 255, 223, 0xE0FFFFFF, 0xE0FFFFFF)
	gui.pixelText(2, 187, l1, 0xFF000000, 0x00000000)
	gui.pixelText(2, 196, l2, 0xFF000000, 0x00000000)
	gui.pixelText(2, 205, l3, 0xFF000000, 0x00000000)
	gui.pixelText(2, 214, l4, 0xFFC00000, 0x00000000)
end

-- ---------------------------- Generalizacion --------------------------------
function ln_buscarMejor()
	local maxf, ms, mg = nil, nil, nil
	for s, species in pairs(pool.species) do
		for g, genome in pairs(species.genomes) do
			if maxf == nil or genome.fitness > maxf then
				maxf = genome.fitness
				ms = s
				mg = g
			end
		end
	end
	lnEstado.mejorS, lnEstado.mejorG, lnEstado.fitnessA = ms, mg, maxf
end

function ln_repetirMejor()
	-- Restaura el fitness obtenido en A (el bucle lo sobrescribio con el de B)
	pool.species[lnEstado.mejorS].genomes[lnEstado.mejorG].fitness = lnEstado.fitnessA
	pool.currentSpecies = lnEstado.mejorS
	pool.currentGenome = lnEstado.mejorG
	initializeRun()
	pool.currentFrame = pool.currentFrame + 1
end

function ln_resultadoGeneralizacion(fitness)
	lnEstado.intentosGeneralizacion = lnEstado.intentosGeneralizacion + 1
	local completo = rightmost > LN.metaX
	local captura = ln_captura("generalizacion")
	ln_append("generalizacion.csv",
		table.concat({ln_fechaHora(), lnEstado.intentosGeneralizacion, LN.poolGeneralizacion, LN.estado,
			ln_num(lnEstado.fitnessA), ln_num(fitness), math.floor(rightmost), pool.currentFrame,
			completo and 1 or 0, captura}, ","),
		"fecha_hora,intento,pool_origen,estado_prueba,fitness_en_A,fitness_en_B,rightmost,frames,completo_nivel,captura")
	ln_pausar(string.format("GENERALIZ. fit B %.1f X %d", fitness, math.floor(rightmost)))
end

-- ------------------------ Carga de .pool (KopiLua) ---------------------------
-- KopiLua (el Lua de BizHawk 2.3.1) lanza un error al llegar al final del archivo
-- con f:lines() y con f:read("*line"). Leer todo con "*a" y separar si funciona.
function ln_leerLineas(ruta)
	local f = io.open(ruta, "r")
	if f == nil then
		return nil
	end
	local contenido = f:read("*a")
	f:close()
	local lineas = {}
	for linea in string.gmatch(contenido, "[^\n]+") do
		lineas[#lineas + 1] = (string.gsub(linea, "\r", ""))
	end
	return lineas
end

-- BizHawk 2.3.1 ejecuta Lua con KopiLua, cuyo file:read("*number") falla en las
-- lineas con varios numeros separados por espacios (una por conexion). Por eso el
-- loadFile() original (y el boton Load) no funcionan en este emulador. Esta funcion
-- lee el MISMO formato que escribe writeFile(), linea por linea, y reconstruye la
-- poblacion con las funciones originales newPool/newSpecies/newGenome/newGene.
function ln_cargarPool(filename)
	local lineas = ln_leerLineas(filename)
	if lineas == nil then
		return false
	end

	local i = 0
	local function leerLinea()
		i = i + 1
		return lineas[i]
	end
	local function leerNumero()
		return tonumber(leerLinea())
	end

	pool = newPool()
	pool.generation = leerNumero()
	pool.maxFitness = leerNumero()
	forms.settext(maxFitnessLabel, "Max Fitness: " .. math.floor(pool.maxFitness))
	local numSpecies = leerNumero()
	for s = 1, numSpecies do
		local species = newSpecies()
		table.insert(pool.species, species)
		species.topFitness = leerNumero()
		species.staleness = leerNumero()
		local numGenomes = leerNumero()
		for g = 1, numGenomes do
			local genome = newGenome()
			table.insert(species.genomes, genome)
			genome.fitness = leerNumero()
			genome.maxneuron = leerNumero()
			local nombre = leerLinea()
			while nombre ~= "done" do
				genome.mutationRates[nombre] = leerNumero()
				nombre = leerLinea()
			end
			local numGenes = leerNumero()
			for n = 1, numGenes do
				local gene = newGene()
				table.insert(genome.genes, gene)
				local a, b, c, d, e = string.match(leerLinea(), "(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)")
				gene.into = tonumber(a)
				gene.out = tonumber(b)
				gene.weight = tonumber(c)
				gene.innovation = tonumber(d)
				gene.enabled = (tonumber(e) ~= 0)
			end
		end
	end
	return true
end

-- --------------------------- Inicio de sesion -------------------------------
function ln_archivarAnteriores()
	local sufijo = os.date("%Y%m%d_%H%M%S")
	for _, nombre in ipairs({"generaciones.csv", "genomas.csv", "eventos.csv"}) do
		local ruta = ln_ruta(nombre)
		if ln_existe(ruta) then
			os.rename(ruta, ruta .. ".anterior_" .. sufijo)
			console.writeline("[SLTG] Registro previo archivado: " .. ruta .. ".anterior_" .. sufijo)
		end
	end
end

function ln_recuperarRegistros()
	local lineasGen = ln_leerLineas(ln_ruta("generaciones.csv"))
	if lineasGen then
		local ultima = lineasGen[#lineasGen]
		local c = ultima and ln_split(ultima) or {}
		if #c >= 19 and tonumber(c[19]) then
			lnEstado.tiempoAcum = tonumber(c[19]) * 60
			lnEstado.inicioGenT = lnEstado.tiempoAcum
			lnEstado.gensSinMejora = tonumber(c[9]) or 0
			lnEstado.estancamientoAvisado = lnEstado.gensSinMejora >= LN.generacionesEstancamiento
			lnEstado.ultimaGenMax = tonumber(c[5])
			lnEstado.ultimaGenProm = tonumber(c[6])
		end
	end
	local lineasEv = ln_leerLineas(ln_ruta("eventos.csv"))
	if lineasEv then
		for _, linea in ipairs(lineasEv) do
			local c = ln_split(linea)
			if c[2] and c[2] ~= "evento" then
				lnEstado.eventos[c[2]] = true
				if c[2] == "META_DETECTADA" and c[10] then
					local m = tonumber(string.match(c[10], "metaX=(%-?%d+)"))
					if m and LN.metaX >= 99999 then
						LN.metaX = m
						console.writeline("[SLTG] Meta recuperada de eventos.csv: LN.metaX = " .. m)
					end
				end
				if c[2] == "NUEVO_RECORD" then
					local fit = tonumber(c[6])
					if fit and (lnEstado.record == nil or fit > lnEstado.record) then
						lnEstado.record = fit
						lnEstado.recordGen = tonumber(c[3]) or 0
					end
				end
			end
		end
	end
	lnEstado.eventos["NUEVO_RECORD"] = nil
end

function ln_inicioSesion()
	-- Usuario de Windows para el timestamp: os.getenv; si BizHawk no lo permite,
	-- se consulta con "echo %USERNAME%"; si tampoco, se usa LN.usuario.
	local ok, u = pcall(os.getenv, "USERNAME")
	if not (ok and u and u ~= "") then
		ok, u = pcall(function()
			local h = io.popen("echo %USERNAME%")
			local r = h:read("*l")
			h:close()
			return r
		end)
	end
	if ok and u and u ~= "" and u ~= "%USERNAME%" then
		lnEstado.usuario = u
	else
		lnEstado.usuario = LN.usuario
	end
	lnEstado.ultimoT = os.time()

	if LN.modo == "generalizacion" then
		LN.carpeta = LN.carpetaGeneralizacion
		Filename = LN.estadoGeneralizacion
		LN.estado = LN.estadoGeneralizacion
		LN.metaX = LN.metaXGeneralizacion
		if LN.poolGeneralizacion == "" or not ln_existe(LN.poolGeneralizacion) then
			lnEstado.mensaje = "Falta LN.poolGeneralizacion o no existe el archivo"
			console.writeline("[SLTG] ERROR: configure LN.poolGeneralizacion con un .pool existente del escenario A.")
			client.pause()
			return
		end
		-- Se carga la poblacion de A sin evaluar ni evolucionar nada (ver ln_cargarPool).
		ln_cargarPool(LN.poolGeneralizacion)
		ln_buscarMejor()
		ln_repetirMejor()
		lnEstado.mensaje = "Jugando mejor individuo de A (fitness " .. ln_num(lnEstado.fitnessA) .. ")"
		console.writeline("[SLTG] Generalizacion: mejor individuo de A con fitness " .. ln_num(lnEstado.fitnessA) ..
			" jugando en " .. LN.estado)
		return
	end

	if LN.poolReanudar ~= "" then
		if not ln_existe(LN.poolReanudar) then
			lnEstado.mensaje = "No existe " .. LN.poolReanudar
			console.writeline("[SLTG] ERROR: no existe el archivo LN.poolReanudar = " .. LN.poolReanudar)
			client.pause()
			return
		end
		ln_recuperarRegistros()
		-- Equivalente a loadFile() original, con el cargador compatible con KopiLua.
		ln_cargarPool(LN.poolReanudar)
		while fitnessAlreadyMeasured() do
			nextGenome()
		end
		initializeRun()
		pool.currentFrame = pool.currentFrame + 1
		lnEstado.ultimoMaxHist = pool.maxFitness
		if lnEstado.record == nil then
			lnEstado.record = pool.maxFitness
		end
		lnEstado.mensaje = "Reanudado desde " .. LN.poolReanudar
		console.writeline("[SLTG] Entrenamiento reanudado desde " .. LN.poolReanudar .. " (generacion " .. ln_gen() .. ")")
	else
		ln_archivarAnteriores()
		console.writeline("[SLTG] Entrenamiento NUEVO del escenario " .. LN.escenario .. " (" .. LN.nombreNivel .. ")")
	end
	if LN.metaX >= 99999 then
		console.writeline("[SLTG] Meta en modo automatico: se fijara al primer cruce de la meta.")
	end
end
-- [SLTG] <<< FIN DE LA INSTRUMENTACION <<<
-- ============================================================================

writeFile("temp.pool")

event.onexit(onExit)

form = forms.newform(200, 260, "Fitness")
maxFitnessLabel = forms.label(form, "Max Fitness: " .. math.floor(pool.maxFitness), 5, 8)
showNetwork = forms.checkbox(form, "Show Map", 5, 30)
showMutationRates = forms.checkbox(form, "Show M-Rates", 5, 52)
restartButton = forms.button(form, "Restart", initializePool, 5, 77)
saveButton = forms.button(form, "Save", savePool, 5, 102)
loadButton = forms.button(form, "Load", loadPool, 80, 102)
saveLoadFile = forms.textbox(form, Filename .. ".pool", 170, 25, nil, 5, 148)
saveLoadLabel = forms.label(form, "Save/Load:", 5, 129)
playTopButton = forms.button(form, "Play Top", playTop, 5, 170)
hideBanner = forms.checkbox(form, "Hide Banner", 5, 190)
ln_inicioSesion() -- [SLTG] archiva/reanuda registros o activa el modo generalizacion


while true do
	local backgroundColor = 0xD0FFFFFF
	if not forms.ischecked(hideBanner) then
		gui.drawBox(0, 0, 300, 26, backgroundColor, backgroundColor)
	end

	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]
	
	if forms.ischecked(showNetwork) then
		displayGenome(genome)
	end
	
	if pool.currentFrame%5 == 0 then
		evaluateCurrent()
	end

	joypad.set(controller)

	getPositions()
	if marioX > rightmost then
		rightmost = marioX
		timeout = TimeoutConstant
	end
	
	timeout = timeout - 1
	
	
	local timeoutBonus = pool.currentFrame / 4
	if timeout + timeoutBonus <= 0 then
		local fitness = rightmost - pool.currentFrame / 2
		if gameinfo.getromname() == "Super Mario World (USA)" and rightmost > LN.metaX then -- [SLTG] original: rightmost > 4816 (meta de Donut Plains 1)
			fitness = fitness + 1000
		end
		if gameinfo.getromname() == "Super Mario Bros." and rightmost > 3186 then
			fitness = fitness + 1000
		end
		if fitness == 0 then
			fitness = -1
		end
		genome.fitness = fitness
		ln_alEvaluarGenoma(genome, fitness) -- [SLTG] registro, capturas y eventos
		if LN.modo == "generalizacion" then -- [SLTG] no evoluciona: repite al mejor individuo de A
			ln_repetirMejor() -- [SLTG]
		else -- [SLTG] desde aqui hasta "fin del else" es el bloque original sin cambios
		
		if fitness > pool.maxFitness then
			pool.maxFitness = fitness
			forms.settext(maxFitnessLabel, "Max Fitness: " .. math.floor(pool.maxFitness))
			writeFile("backup." .. pool.generation .. "." .. forms.gettext(saveLoadFile))
		end
		
		console.writeline("Gen " .. pool.generation .. " species " .. pool.currentSpecies .. " genome " .. pool.currentGenome .. " fitness: " .. fitness)
		pool.currentSpecies = 1
		pool.currentGenome = 1
		while fitnessAlreadyMeasured() do
			nextGenome()
		end
		initializeRun()
		end -- [SLTG] fin del else
	end

	local measured = 0
	local total = 0
	for _,species in pairs(pool.species) do
		for _,genome in pairs(species.genomes) do
			total = total + 1
			if genome.fitness ~= 0 then
				measured = measured + 1
			end
		end
	end
	if not forms.ischecked(hideBanner) then
		gui.drawText(0, 0, "Gen " .. pool.generation .. " species " .. pool.currentSpecies .. " genome " .. pool.currentGenome .. " (" .. math.floor(measured/total*100) .. "%)", 0xFF000000, 11)
		gui.drawText(0, 12, "Fitness: " .. math.floor(rightmost - (pool.currentFrame) / 2 - (timeout + timeoutBonus)*2/3), 0xFF000000, 11)
		gui.drawText(100, 12, "Max Fitness: " .. math.floor(pool.maxFitness), 0xFF000000, 11)
	end
		
	pool.currentFrame = pool.currentFrame + 1

	ln_cadaFrame() -- [SLTG] tiempo de entrenamiento y panel con fecha/hora/usuario
	emu.frameadvance();
end
