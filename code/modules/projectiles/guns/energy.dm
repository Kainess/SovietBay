/obj/item/weapon/gun/energy
	name = "energy gun"
	desc = "A basic energy-based gun."
	icon_state = "energy"
	fire_sound = 'sound/weapons/Taser.ogg'
	fire_sound_text = "laser blast"
	fire_delay = 1

	var/obj/item/weapon/cell/power_supply //What type of power cell this uses
	var/charge_cost = 100 //How much energy is needed to fire.
	var/cell_type = /obj/item/weapon/cell
	var/projectile_type = /obj/item/projectile/beam/practice
	var/modifystate
	var/charge_meter = 1	//if set, the icon state will be chosen based on the current charge

	//self-recharging
	var/self_recharge = 0	//if set, the weapon will recharge itself
	var/use_external_power = 0 //if set, the weapon will look for an external power source to draw from, otherwise it recharges magically
	var/recharge_time = 4
	var/charge_tick = 0

/obj/item/weapon/gun/energy/emp_act(severity)
	power_supply.use(round(power_supply.maxcharge / severity))
	..()
	update_icon()

/obj/item/weapon/gun/energy/New()
	..()
	if(cell_type)
		power_supply = new cell_type(src)
		power_supply.give(power_supply.maxcharge)
	if(self_recharge)
		processing_objects.Add(src)
	update_icon()

/obj/item/weapon/gun/energy/Del()
	if(self_recharge)
		processing_objects.Remove(src)
	..()

/obj/item/weapon/gun/energy/process()
	if(self_recharge) //Every [recharge_time] ticks, recharge a shot for the cyborg
		charge_tick++
		if(charge_tick < recharge_time) return 0
		charge_tick = 0

		if(!power_supply || power_supply.charge >= power_supply.maxcharge)
			return 0 // check if we actually need to recharge

		if(use_external_power)
			var/obj/item/weapon/cell/external = get_external_power_supply()
			if(!external || !external.use(charge_cost)) //Take power from the borg...
				return 0

		power_supply.give(charge_cost) //... to recharge the shot
		update_icon()
	return 1

/obj/item/weapon/gun/energy/consume_next_projectile()
	if(!power_supply) return null
	if(!ispath(projectile_type)) return null
	if(!power_supply.checked_use(charge_cost)) return null
	return new projectile_type(src)

/obj/item/weapon/gun/energy/proc/get_external_power_supply()
	if(isrobot(src.loc))
		var/mob/living/silicon/robot/R = src.loc
		return R.cell
	if(istype(src.loc, /obj/item/rig_module))
		var/obj/item/rig_module/module = src.loc
		if(module.holder && module.holder.wearer)
			var/mob/living/carbon/human/H = module.holder.wearer
			if(istype(H) && H.back)
				var/obj/item/weapon/rig/suit = H.back
				if(istype(suit))
					return suit.cell
	return null

/obj/item/weapon/gun/energy/update_icon()
	if(charge_meter)
		if(!power_supply)
			icon_state = "[modifystate ? modifystate : initial(icon_state)]0"
			return

		var/ratio = power_supply.charge / power_supply.maxcharge

		//make sure that rounding down will not give us the empty state even if we have charge for a shot left.
		if(power_supply.charge < charge_cost)
			ratio = 0
		else
			ratio = max(round(ratio, 0.25) * 100, 25)

		icon_state = "[modifystate ? modifystate : initial(icon_state)][ratio]"

/obj/item/weapon/gun/energy/attackby(obj/item/weapon/O as obj, mob/user as mob)
	if(istype(O, /obj/item/weapon/cell))
		if(!power_supply)
			if(user)
				user.drop_item(O)
				user.visible_message("[user] loaded a cell into [src]", "You loaded a cell into [src]")
				O.loc = src
				power_supply = O
			update_icon()
			return
		else
			usr << "<span class='notice'>Cell is already loaded.</span>"
			return
	..()

/obj/item/weapon/gun/energy/verb/EjectCell()
	set name = "Eject Cell"
	set category = "Object"

	if(self_recharge)
		usr << "<span class='notice'>You can`t directly remove a cell from [src]</span>"
		return
	if(power_supply)
		if(usr)
			power_supply.loc = usr.loc
			usr.put_in_hands(power_supply)
			power_supply = null
			usr << "<span class='notice'>You eject a cell from [src].</span>"
		update_icon()
	else
		usr << "<span class='warning'>Cell is already ejected.</span>"