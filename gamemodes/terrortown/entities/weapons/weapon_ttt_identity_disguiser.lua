if SERVER then
	AddCSLuaFile()

	resource.AddFile("materials/vgui/ttt/icon_identity_disguiser.vmt")
	resource.AddFile("materials/vgui/ttt/icon_identity_disguised_hud.vmt")
end

SWEP.Base = "weapon_tttbase"

if CLIENT then
	SWEP.ViewModelFOV = 78
	SWEP.DrawCrosshair = false
	SWEP.ViewModelFlip = false

	SWEP.EquipMenuData = {
		type = "item_weapon",
		name = "weapon_indentiy_disguiser_name",
		desc = "weapon_indentiy_disguiser_desc"
	}

	SWEP.Icon = "vgui/ttt/icon_identity_disguiser"
end

SWEP.Kind = WEAPON_EQUIP2
SWEP.CanBuy = {ROLE_TRAITOR, ROLE_DETECTIVE}

SWEP.HoldType = "knife"
SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/cstrike/c_knife_t.mdl"
SWEP.WorldModel = "models/weapons/w_knife_t.mdl"

SWEP.AutoSpawnable = false
SWEP.NoSights = true

SWEP.LimitedStock = true

SWEP.Primary.Recoil = 0
SWEP.Primary.ClipSize = 5
SWEP.Primary.DefaultClip = 5
SWEP.Primary.Automatic = false
SWEP.Primary.Delay = 1
SWEP.Primary.Ammo = "none"

SWEP.Secondary.Recoil = 0
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Delay = 0.5

function SWEP:PrimaryAttack()
	local owner = self:GetOwner()

	owner:SetAnimation(PLAYER_ATTACK1)
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)

	if CLIENT then return end

	local trace = owner:GetEyeTrace()
	local distance = trace.StartPos:Distance(trace.HitPos)
	local ent = trace.Entity

	if not IsValid(ent) or distance > 100 then return end

	if ent:IsPlayer() then
		owner:UpdateStoredDisguiserTarget(ent, ent:GetModel(), ent:GetSkin())
		owner:DeactivateDisguiserTarget()
	elseif ent:GetClass() == "prop_ragdoll" and CORPSE.IsValidBody(ent) then
		owner:UpdateStoredDisguiserTarget(CORPSE.GetPlayer(ent), ent:GetModel(), ent:GetSkin())
		owner:DeactivateDisguiserTarget()
	end
end

function SWEP:SecondaryAttack()
	if CLIENT then return end

	local owner = self:GetOwner()

	owner:ToggleDisguiserTarget()
end

function SWEP:Reload()
	if CLIENT then return end

	local owner = self:GetOwner()

	owner:DeactivateDisguiserTarget()
	owner:UpdateStoredDisguiserTarget(nil)
end

if SERVER then
	function SWEP:Deploy()
		self.BaseClass.Deploy(self)

		-- store owner in extra variable because the owner isn't valid
		-- once OnDrop is called
		self.notifyOwner = self:GetOwner()
	end

	function SWEP:OnDrop()
		self.BaseClass.OnDrop(self)

		if not IsValid(self.notifyOwner) then return end

		self.notifyOwner:DeactivateDisguiserTarget()
		self.notifyOwner:UpdateStoredDisguiserTarget(nil)

		self.notifyOwner = nil
	end
end

if CLIENT then
	function SWEP:Initialize()
		self:AddTTT2HUDHelp("idisguise_help_msb1", "idisguise_help_msb2")
		self:AddHUDHelpLine("idisguise_help_rld", Key("+reload", "R"))
	end

	local function EvilTeammate(ply)
		local client = LocalPlayer()
		return (not client:IsInnocent()) and ply:IsInTeam(client)
	end

	local function ModifyTarget(oldPly)
		if not oldPly:IsPlayer() or not oldPly:HasDisguiserTarget() then return end

		if EvilTeammate(oldPly) then return end

		return oldPly:GetDisguiserTarget()
	end

	hook.Add("TTTModifyTargetedEntity", "ttt2_identity_disguiser_change_ent", ModifyTarget)
	hook.Add("TTT2ModifyRadioTarget", "ttt2_identity_disguiser_change_ent_radio", ModifyTarget)

	hook.Add("TTT2ModifyOverheadIcon", "ModifyDisguiserOHI", function(ply, shouldDrawDefault)
		if not ply:IsPlayer() or not ply:HasDisguiserTarget() then return end

		if EvilTeammate(ply) then return end

		local client = LocalPlayer()
		local target = ply:GetDisguiserTarget()
		local rd = target:GetSubRoleData()

		local shouldShow = target:IsActive()
			and target:HasRole()
			and (not client:IsActive() or target:IsInTeam(client) or rd.isPublicRole)
			and not rd.avoidTeamIcons

		return shouldShow, target:GetSubRoleData().iconMaterial, target:GetRoleColor()
	end)

	hook.Add("TTTRenderEntityInfo", "ttt2_identity_disguiser_update_data", function(tData)
		local unchangedEnt = tData:GetUnchangedEntity()
		local ent = tData:GetEntity()
		local disguiserTarget = unchangedEnt:GetDisguiserTarget()

		-- has to be a player
		if not IsPlayer(ent) then return end

		if not IsValid(unchangedEnt) or not IsPlayer(unchangedEnt) then return end

		-- if a teammate is looking at the disguised player, tell them who they're disguising as
		if EvilTeammate(ent) then
			tData:AddDescriptionLine(
				LANG.GetParamTranslation("identity_disguiser_targetid_teammate", disguiserTarget:Nick()),
				COLOR_ORANGE
			)

		if disguiserTarget ~= ent then return end

		-- add title and subtitle to the focused ent
		local h_string, h_color = util.HealthToString(unchangedEnt:Health(), unchangedEnt:GetMaxHealth())

		tData:SetSubtitle(
			LANG.TryTranslation(h_string),
			h_color
		)
	end)
end

if SERVER then
	hook.Add("TTTPrepareRound", "ttt2_identity_disguiser_reset", function()
		local plys = player.GetAll()

		for i = 1, #plys do
			local ply = plys[i]

			ply:DeactivateDisguiserTarget()
			ply:UpdateStoredDisguiserTarget(nil)
		end
	end)
end
