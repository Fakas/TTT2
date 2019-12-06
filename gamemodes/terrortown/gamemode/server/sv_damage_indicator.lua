
util.AddNetworkString("ttt2_damage_received")

hook.Add("EntityTakeDamage","TTT2DamageIndicator",function(ent,dmg)
	if ent:IsPlayer() and dmg and dmg:GetDamage() > 0 then
		net.Start("ttt2_damage_received")
		net.WriteFloat( dmg:GetDamage() )
		net.Send( ent )
	end
end)