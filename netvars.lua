--[[----------------------------------------
	Name:    Bundle.Network.NetVars 
	Author:  Sdam64
	Purpose: Both side data keeping
------------------------------------------]]

if (SERVER) then 
	util.AddNetworkString("Bundle.Network.NetVars")
	util.AddNetworkString("Bundle.Network.NetVars.Stream")
	function DataStream(addr, data, target, dataset, section)
		net["Start"](addr)
			net["WriteString"](section)
			net["WriteTable"](data)
			net["WriteEntity"](dataset)
		net["Send"](target)
	end

	net.Receive("Bundle.Network.NetVars", function(len, ply) 
		local buff  = {}
		for key, ent in next, ents.GetAll() do 
			if ent.NW == nil then continue end
			local nw = ent["NW"]
			buff[#buff + 1] = {ent:EntIndex()}
			for var, value in next, nw do 
				buff[#buff][var] = value 
			end
		end

		local serialize = util["Compress"](util.TableToJSON(buff));
		local function deepSize(tb, depth)
			local buff = depth
			for k, v in next, tb do 
				if (istable(v)) then 
					buff = buff + deepSize(v, buff)
				else
					buff = buff + 1
				end
			end

			return buff
		end
		-- print(deepSize(buff, 0))
		net.Start("Bundle.Network.NetVars.Stream")
			net.WriteInt( (deepSize(buff, 0) + serialize:len()), 8 )
			net.WriteData(util.TableToJSON(buff), (deepSize(buff, 0) + serialize:len()))
		net.Send(ply)
	end)
end
if (CLIENT) then 
	net.Receive("Bundle.Network.NetVars.Stream", function(len, ply) 
		if (ply ~= nil) then return end // preventing p2p running 
		local size  = net.ReadInt(8)   
		local chunk = net.ReadData(size) 
		
		local deserialize = util.JSONToTable(chunk)
		PrintTable(deserialize)

		for k, v in next, deserialize do 
			local index = v[1]
			local ent   = Entity(index)

			ent.NW = ent.NW or {}
			for _, inv in next, v do 
				if (isnumber(_)) then continue end 
				ent.NW[_] = inv
			end
		end
	end)
	net.Receive("Bundle.Network.NetVars", function(len, ply) 
		if ply ~= nil then return end 
		local section = net.ReadString()
		local data    = net.ReadTable() 
		local dataset = net.ReadEntity()

		dataset["NW"] = dataset["NW"] or {}
		dataset["NW"][section] = data

		print("setup for", dataset, section, data)
	end)

	//Hooks 
	hook.Add("InitPostEntity", "Bundle.Network.Hooks.RequestGlobalNW", function() 
		net.Start("Bundle.Network.NetVars")
		net.SendToServer()
	end)
end

local PLAYER = debug.getregistry()["Entity"]

function PLAYER:SetNetVar( data, value )
	self.NW = self.NW or {}
	if (SERVER) then 
		self.NW[tostring(data)] = value
		for k, v in next, player.GetAll() do 
			local addr = self.NW[tostring(data)]
			DataStream("Bundle.Network.NetVars",istable(addr) and addr or {addr}, v,self, tostring(data))
		end
	else
		self.NW[tostring(data)] = value 
	end
end

function PLAYER:GetNetVar( data )
	local ret = nil
	if (SERVER) then 
		ret = (
			self.NW != nil and (
				self.NW[data]
			)
		)
	else
		ret = (
			self.NW != nil and (
				self.NW[data] != nil and 
				(
					(self.NW[data][1] != nil and #self.NW[data] < 2) and self.NW[data][1] or self.NW[data]
				)
			)
		)
	end

	return ret
end
