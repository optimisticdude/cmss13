/mob/living/carbon/human/Initialize(mapload, new_species = null)
	blood_type = pick(7;"O-", 38;"O+", 6;"A-", 34;"A+", 2;"B-", 9;"B+", 1;"AB-", 3;"AB+")
	GLOB.human_mob_list += src
	GLOB.alive_human_list += src
	SShuman.processable_human_list += src

	if(!species)
		if(new_species)
			set_species(new_species)
		else
			set_species()

	create_reagents(1000)
	change_real_name(src, "unknown")

	. = ..()

	prev_gender = gender // Debug for plural genders

	if(SSticker?.mode?.hardcore)
		hardcore = TRUE //For WO disposing of corpses

/mob/living/carbon/human/initialize_pass_flags(var/datum/pass_flags_container/PF)
	..()
	if (PF)
		PF.flags_pass = PASS_MOB_IS_HUMAN
		PF.flags_can_pass_all = PASS_MOB_THRU_HUMAN|PASS_AROUND|PASS_HIGH_OVER_ONLY

/mob/living/carbon/human/prepare_huds()
	..()
	//updating all the mob's hud images
	med_hud_set_health()
	med_hud_set_armor()
	med_hud_set_status()
	sec_hud_set_ID()
	sec_hud_set_security_status()
	hud_set_squad()
	//and display them
	add_to_all_mob_huds()

/mob/living/carbon/human/initialize_pain()
	if(species)
		return species.initialize_pain(src)
	QDEL_NULL(pain)
	pain = new /datum/pain/human(src)

/mob/living/carbon/human/initialize_stamina()
	if(species)
		return species.initialize_stamina(src)
	QDEL_NULL(stamina)
	stamina = new /datum/stamina(src)

/mob/living/carbon/human/proc/initialize_wounds()
	if(length(limb_wounds))
		for(var/limb in limb_wounds)
			for(var/wound in limb_wounds[limb])
				qdel(wound)
	else
		for(var/obj/limb/limbloop as anything in limbs)
			limb_wounds[limbloop.name] = list()

/mob/living/carbon/human/Destroy()
	if(internal_organs_by_name)
		for(var/name in internal_organs_by_name)
			var/datum/internal_organ/I = internal_organs_by_name[name]
			if(I)
				I.owner = null
			internal_organs_by_name[name] = null
		internal_organs_by_name = null

	if(limbs)
		for(var/obj/limb/L in limbs)
			L.owner = null
			qdel(L)
		limbs = null

	remove_from_all_mob_huds()
	GLOB.human_mob_list -= src
	GLOB.alive_human_list -= src
	SShuman.processable_human_list -= src

	. = ..()

/mob/living/carbon/human/get_status_tab_items()
	. = ..()

	. += ""
	. += "Security Level: [uppertext(get_security_level())]"

	if(faction == FACTION_MARINE & !isnull(SSticker) && !isnull(SSticker.mode) && !isnull(SSticker.mode.active_lz) && !isnull(SSticker.mode.active_lz.loc) && !isnull(SSticker.mode.active_lz.loc.loc))
		. += "Primary LZ: [SSticker.mode.active_lz.loc.loc.name]"

	if(assigned_squad)
		if(assigned_squad.overwatch_officer)
			. += "Overwatch Officer: [assigned_squad.overwatch_officer.get_paygrade()][assigned_squad.overwatch_officer.name]"
		if(assigned_squad.primary_objective)
			. += "Primary Objective: [html_decode(assigned_squad.primary_objective)]"
		if(assigned_squad.secondary_objective)
			. += "Secondary Objective: [html_decode(assigned_squad.secondary_objective)]"

	if(mobility_aura)
		. += "Active Order: MOVE"
	if(protection_aura)
		. += "Active Order: HOLD"
	if(marksman_aura)
		. += "Active Order: FOCUS"

	if(EvacuationAuthority)
		var/eta_status = EvacuationAuthority.get_status_panel_eta()
		if(eta_status)
			. += eta_status

/mob/living/carbon/human/ex_act(var/severity, var/direction, var/datum/cause_data/cause_data)
	if(lying)
		severity *= EXPLOSION_PRONE_MULTIPLIER

	if(severity >= 30)
		flash_eyes()

	var/b_loss = 0
	var/f_loss = 0

	var/damage = severity

	damage = armor_damage_reduction(GLOB.marine_explosive, damage, getarmor(null, ARMOR_BOMB))

	last_damage_data = cause_data

	if(damage >= EXPLOSION_THRESHOLD_GIB)
		var/oldloc = loc
		gib(cause_data)
		create_shrapnel(oldloc, rand(5, 9), direction, 45, /datum/ammo/bullet/shrapnel/light/human, cause_data)
		sleep(1)
		create_shrapnel(oldloc, rand(5, 9), direction, 30, /datum/ammo/bullet/shrapnel/light/human/var1, cause_data)
		create_shrapnel(oldloc, rand(5, 9), direction, 45, /datum/ammo/bullet/shrapnel/light/human/var2, cause_data)
		return

	if(!get_type_in_ears(/obj/item/clothing/ears/earmuffs))
		ear_damage += severity * 0.15
		AdjustEarDeafness(severity * 0.5)

	var/knockdown_value = min( round( severity*0.1  ,1) ,10)
	if(knockdown_value > 0)
		var/obj/item/Item1 = get_active_hand()
		var/obj/item/Item2 = get_inactive_hand()
		KnockDown(knockdown_value)
		var/knockout_value = min( round( damage*0.1  ,1) ,10)
		KnockOut( knockout_value )
		Daze( knockout_value*2 )
		explosion_throw(severity, direction)

		if(Item1 && isturf(Item1.loc))
			Item1.explosion_throw(severity, direction)
		if(Item2 && isturf(Item2.loc))
			Item2.explosion_throw(severity, direction)

	if(damage >= 0)
		b_loss += damage * 0.5
		f_loss += damage * 0.5
	else
		return

	var/update = 0

	//Focus half the blast on one organ
	var/obj/limb/take_blast = pick(limbs)
	update |= take_blast.take_damage(b_loss * 0.5, f_loss * 0.5, used_weapon = "Explosive blast", attack_source = cause_data.resolve_mob())
	pain.apply_pain(b_loss * 0.5, BRUTE)
	pain.apply_pain(f_loss * 0.5, BURN)

	//Distribute the remaining half all limbs equally
	b_loss *= 0.5
	f_loss *= 0.5

	var/weapon_message = "Explosive Blast"
	var/limb_multiplier = 0.05
	for(var/obj/limb/temp in limbs)
		switch(temp.name)
			if("head")
				limb_multiplier = 0.2
			if("chest")
				limb_multiplier = 0.4
			if("l_arm")
				limb_multiplier = 0.05
			if("r_arm")
				limb_multiplier = 0.05
			if("l_leg")
				limb_multiplier = 0.05
			if("r_leg")
				limb_multiplier = 0.05
			if("r_foot")
				limb_multiplier = 0.05
			if("l_foot")
				limb_multiplier = 0.05
			if("r_arm")
				limb_multiplier = 0.05
			if("l_arm")
				limb_multiplier = 0.05
		update |= temp.take_damage(b_loss * limb_multiplier, f_loss * limb_multiplier, used_weapon = weapon_message, attack_source = cause_data.resolve_mob())
		pain.apply_pain(b_loss * limb_multiplier, BRUTE)
		pain.apply_pain(f_loss * limb_multiplier, BURN)
	if(update)
		UpdateDamageIcon()
	return TRUE


/mob/living/carbon/human/attack_animal(mob/living/M as mob)
	if(M.melee_damage_upper == 0)
		M.emote("[M.friendly] [src]")
	else
		if(M.attack_sound)
			playsound(loc, M.attack_sound, 25, 1)
		for(var/mob/O in viewers(src, null))
			O.show_message(SPAN_DANGER("<B>[M]</B> [M.attacktext] [src]!"), 1)
		last_damage_data = create_cause_data(initial(M.name), M)
		M.attack_log += text("\[[time_stamp()]\] <font color='red'>attacked [key_name(src)]</font>")
		src.attack_log += text("\[[time_stamp()]\] <font color='orange'>was attacked by [key_name(M)]</font>")
		var/damage = rand(M.melee_damage_lower, M.melee_damage_upper)
		var/dam_zone = pick("chest", "l_hand", "r_hand", "l_leg", "r_leg")
		var/obj/limb/affecting = get_limb(rand_zone(dam_zone))
		apply_damage(damage, BRUTE, affecting)


/mob/living/carbon/human/proc/implant_loyalty(mob/living/carbon/human/M, override = FALSE) // Won't override by default.
	if(!CONFIG_GET(flag/use_loyalty_implants) && !override) return // Nuh-uh.

	var/obj/item/implant/loyalty/L = new/obj/item/implant/loyalty(M)
	L.imp_in = M
	L.implanted = 1
	var/obj/limb/affected = M.get_limb("head")
	affected.implants += L
	L.part = affected

/mob/living/carbon/human/proc/is_loyalty_implanted(mob/living/carbon/human/M)
	for(var/L in M.contents)
		if(istype(L, /obj/item/implant/loyalty))
			for(var/obj/limb/O in M.limbs)
				if(L in O.implants)
					return TRUE
	return FALSE



/mob/living/carbon/human/show_inv(mob/living/user)
	if(ismaintdrone(user))
		return
	var/obj/item/clothing/under/suit = null
	if(istype(w_uniform, /obj/item/clothing/under))
		suit = w_uniform

	user.set_interaction(src)
	var/dat = {"
	<B><HR><FONT size=3>[name]</FONT></B>
	<BR><HR>
	<BR><B>Head(Mask):</B> <A href='?src=\ref[src];item=[WEAR_FACE]'>[(wear_mask ? wear_mask : "Nothing")]</A>
	<BR><B>Left Hand:</B> <A href='?src=\ref[src];item=[WEAR_L_HAND]'>[(l_hand ? l_hand  : "Nothing")]</A>
	<BR><B>Right Hand:</B> <A href='?src=\ref[src];item=[WEAR_R_HAND]'>[(r_hand ? r_hand : "Nothing")]</A>
	<BR><B>Gloves:</B> <A href='?src=\ref[src];item=[WEAR_HANDS]'>[(gloves ? gloves : "Nothing")]</A>
	<BR><B>Eyes:</B> <A href='?src=\ref[src];item=[WEAR_EYES]'>[(glasses ? glasses : "Nothing")]</A>
	<BR><B>Left Ear:</B> <A href='?src=\ref[src];item=[WEAR_L_EAR]'>[(wear_l_ear ? wear_l_ear : "Nothing")]</A>
	<BR><B>Right Ear:</B> <A href='?src=\ref[src];item=[WEAR_R_EAR]'>[(wear_r_ear ? wear_r_ear : "Nothing")]</A>
	<BR><B>Head:</B> <A href='?src=\ref[src];item=[WEAR_HEAD]'>[(head ? head : "Nothing")]</A>
	<BR><B>Shoes:</B> <A href='?src=\ref[src];item=[WEAR_FEET]'>[(shoes ? shoes : "Nothing")]</A>
	<BR><B>Belt:</B> <A href='?src=\ref[src];item=[WEAR_WAIST]'>[(belt ? belt : "Nothing")]</A> [((istype(wear_mask, /obj/item/clothing/mask) && istype(belt, /obj/item/tank) && !internal) ? " <A href='?src=\ref[src];internal=1'>Set Internal</A>" : "")]
	<BR><B>Uniform:</B> <A href='?src=\ref[src];item=[WEAR_BODY]'>[(w_uniform ? w_uniform : "Nothing")]</A> [(suit) ? ((suit.has_sensor == 1) ? " <A href='?src=\ref[src];sensor=1'>Sensors</A>" : "") : null]
	<BR><B>(Exo)Suit:</B> <A href='?src=\ref[src];item=[WEAR_JACKET]'>[(wear_suit ? wear_suit : "Nothing")]</A>
	<BR><B>Back:</B> <A href='?src=\ref[src];item=[WEAR_BACK]'>[(back ? back : "Nothing")]</A> [((istype(wear_mask, /obj/item/clothing/mask) && istype(back, /obj/item/tank) && !( internal )) ? " <A href='?src=\ref[src];internal=1'>Set Internal</A>" : "")]
	<BR><B>ID:</B> <A href='?src=\ref[src];item=[WEAR_ID]'>[(wear_id ? wear_id : "Nothing")]</A>
	<BR><B>Suit Storage:</B> <A href='?src=\ref[src];item=[WEAR_J_STORE]'>[(s_store ? s_store : "Nothing")]</A> [((istype(wear_mask, /obj/item/clothing/mask) && istype(s_store, /obj/item/tank) && !( internal )) ? " <A href='?src=\ref[src];internal=1'>Set Internal</A>" : "")]
	<BR><B>Left Pocket:</B> <A href='?src=\ref[src];item=[WEAR_L_STORE]'>[(l_store ? l_store : "Nothing")]</A>
	<BR><B>Right Pocket:</B> <A href='?src=\ref[src];item=[WEAR_R_STORE]'>[(r_store ? r_store : "Nothing")]</A>
	<BR>
	[handcuffed ? "<BR><A href='?src=\ref[src];item=[WEAR_HANDCUFFS]'>Handcuffed</A>" : ""]
	[legcuffed ? "<BR><A href='?src=\ref[src];item=[WEAR_LEGCUFFS]'>Legcuffed</A>" : ""]
	[suit && LAZYLEN(suit.accessories) ? "<BR><A href='?src=\ref[src];tie=1'>Remove Accessory</A>" : ""]
	[internal ? "<BR><A href='?src=\ref[src];internal=1'>Remove Internal</A>" : ""]
	[istype(wear_id, /obj/item/card/id/dogtag) ? "<BR><A href='?src=\ref[src];item=id'>Retrieve Info Tag</A>" : ""]
	<BR><A href='?src=\ref[src];limbitems=1'>Check items in limbs</A>
	<BR>
	<BR><A href='?src=\ref[user];refresh=1'>Refresh</A>
	<BR><A href='?src=\ref[user];mach_close=mob[name]'>Close</A>
	<BR>"}
	show_browser(user, dat, name, "mob[name]")

// called when something steps onto a human
// this handles mulebots and vehicles
/mob/living/carbon/human/Crossed(var/atom/movable/AM)
	if(istype(AM, /obj/structure/machinery/bot/mulebot))
		var/obj/structure/machinery/bot/mulebot/MB = AM
		MB.RunOver(src)

	if(istype(AM, /obj/vehicle))
		var/obj/vehicle/V = AM
		V.RunOver(src)


//gets assignment from ID or ID inside PDA or PDA itself
//Useful when player do something with computers
/mob/living/carbon/human/proc/get_assignment(var/if_no_id = "No id", var/if_no_job = "No job")
	var/obj/item/card/id/id = wear_id
	if(istype(id))
		. = id.assignment
	else
		return if_no_id
	if(!.)
		. = if_no_job
	return

//gets name from ID or ID inside PDA or PDA itself
//Useful when player do something with computers
/mob/living/carbon/human/proc/get_authentification_name(var/if_no_id = "Unknown")
	var/obj/item/card/id/id = wear_id
	if(istype(id))
		. = id.registered_name
	else
		return if_no_id
	return

//gets paygrade from ID
//paygrade is a user's actual rank, as defined on their ID.  size 1 returns an abbreviation, size 0 returns the full rank name, the third input is used to override what is returned if no paygrade is assigned.
/mob/living/carbon/human/proc/get_paygrade(size = 1)
	if(!species)
		return ""

	switch(species.name)
		if("Human","Human Hero")
			var/obj/item/card/id/id = wear_id
			if(istype(id))
				. = get_paygrades(id.paygrade, size, gender)
		else
			return ""


//repurposed proc. Now it combines get_id_name() and get_face_name() to determine a mob's name variable. Made into a seperate proc as it'll be useful elsewhere
/mob/living/carbon/human/proc/get_visible_name()
	if(wear_mask && (wear_mask.flags_inv_hide & HIDEFACE) )	//Wearing a mask which hides our face, use id-name if possible
		return get_id_name("Unknown")
	if(head && (head.flags_inv_hide & HIDEFACE) )
		return get_id_name("Unknown")		//Likewise for hats
	var/face_name = get_face_name()
	var/id_name = get_id_name("")
	if(id_name && (id_name != face_name))
		return "[face_name] (as [id_name])"
	return face_name

//Returns "Unknown" if facially disfigured and real_name if not. Useful for setting name when polyacided or when updating a human's name variable
/mob/living/carbon/human/proc/get_face_name()
	var/obj/limb/head/head = get_limb("head")
	if(!head || head.disfigured || (head.status & LIMB_DESTROYED) || !real_name)	//disfigured. use id-name if possible
		return "Unknown"
	return real_name

//gets name from ID or PDA itself, ID inside PDA doesn't matter
//Useful when player is being seen by other mobs
/mob/living/carbon/human/proc/get_id_name(var/if_no_id = "Unknown")
	. = if_no_id
	if(wear_id)
		var/obj/item/card/id/I = wear_id.GetID()
		if(I)
			return I.registered_name
	return

//gets ID card object from special clothes slot or null.
/mob/living/carbon/human/proc/get_idcard()
	if(wear_id)
		return wear_id.GetID()

//Removed the horrible safety parameter. It was only being used by ninja code anyways.
//Now checks siemens_coefficient of the affected area by default
/mob/living/carbon/human/electrocute_act(var/shock_damage, var/obj/source, var/base_siemens_coeff = 1.0, var/def_zone = null)
	if(status_flags & GODMODE)	return FALSE	//godmode

	if(!def_zone)
		def_zone = pick("l_hand", "r_hand")

	var/obj/limb/affected_organ = get_limb(check_zone(def_zone))
	var/siemens_coeff = base_siemens_coeff * get_siemens_coefficient_organ(affected_organ)

	return ..(shock_damage, source, siemens_coeff, def_zone)


/mob/living/carbon/human/Topic(href, href_list)
	if(href_list["refresh"])
		if(interactee&&(in_range(src, usr)))
			show_inv(interactee)

	if(href_list["mach_close"])
		var/t1 = text("window=[]", href_list["mach_close"])
		unset_interaction()
		close_browser(src, t1)


	if(href_list["item"])
		if(!usr.is_mob_incapacitated() && Adjacent(usr))
			if(href_list["item"] == "id")
				if(MODE_HAS_TOGGLEABLE_FLAG(MODE_NO_STRIPDRAG_ENEMY) && (stat == DEAD || health < HEALTH_THRESHOLD_CRIT) && !get_target_lock(usr.faction_group))
					to_chat(usr, SPAN_WARNING("You can't strip a crit or dead member of another faction!"))
					return
				if(istype(wear_id, /obj/item/card/id/dogtag) && (undefibbable || !skillcheck(usr, SKILL_POLICE, SKILL_POLICE_SKILLED)))
					var/obj/item/card/id/dogtag/DT = wear_id
					if(!DT.dogtag_taken)
						if(stat == DEAD)
							to_chat(usr, SPAN_NOTICE("You take [src]'s information tag, leaving the ID tag"))
							DT.dogtag_taken = TRUE
							DT.icon_state = "dogtag_taken"
							var/obj/item/dogtag/D = new(loc)
							D.fallen_names = list(DT.registered_name)
							D.fallen_assgns = list(DT.assignment)
							D.fallen_blood_types = list(DT.blood_type)
							usr.put_in_hands(D)
						else
							to_chat(usr, SPAN_WARNING("You can't take a dogtag's information tag while its owner is alive."))
					else
						to_chat(usr, SPAN_WARNING("Someone's already taken [src]'s information tag."))
					return
			//police skill lets you strip multiple items from someone at once.
			if(!usr.action_busy || skillcheck(usr, SKILL_POLICE, SKILL_POLICE_SKILLED))
				var/slot = href_list["item"]
				var/obj/item/what = get_item_by_slot(slot)
				if(MODE_HAS_TOGGLEABLE_FLAG(MODE_NO_STRIPDRAG_ENEMY) && (stat == DEAD || health < HEALTH_THRESHOLD_CRIT) && !get_target_lock(usr.faction_group))
					if(!MODE_HAS_TOGGLEABLE_FLAG(MODE_STRIP_NONUNIFORM_ENEMY) || (what in list(head, wear_suit, w_uniform, shoes)))
						to_chat(usr, SPAN_WARNING("You can't strip a crit or dead member of another faction!"))
						return
				if(what)
					usr.stripPanelUnequip(what,src,slot)
				else
					what = usr.get_active_hand()
					usr.stripPanelEquip(what,src,slot)

	if(href_list["internal"])

		if(!usr.action_busy)
			attack_log += text("\[[time_stamp()]\] <font color='orange'>Has had their internals toggled by [key_name(usr)]</font>")
			usr.attack_log += text("\[[time_stamp()]\] <font color='red'>Attempted to toggle [key_name(src)]'s' internals</font>")
			if(internal)
				usr.visible_message(SPAN_DANGER("<B>[usr] is trying to disable [src]'s internals</B>"), null, null, 3)
			else
				usr.visible_message(SPAN_DANGER("<B>[usr] is trying to enable [src]'s internals.</B>"), null, null, 3)

			if(do_after(usr, POCKET_STRIP_DELAY, INTERRUPT_ALL, BUSY_ICON_GENERIC, src, INTERRUPT_MOVED, BUSY_ICON_GENERIC))
				if(internal)
					internal.add_fingerprint(usr)
					internal = null
					visible_message("[src] is no longer running on internals.", null, null, 1)
				else
					if(istype(wear_mask, /obj/item/clothing/mask))
						if(istype(back, /obj/item/tank))
							internal = back
						else if(istype(s_store, /obj/item/tank))
							internal = s_store
						else if(istype(belt, /obj/item/tank))
							internal = belt
						if(internal)
							visible_message(SPAN_NOTICE("[src] is now running on internals."), null, null, 1)
							internal.add_fingerprint(usr)

				// Update strip window
				if(usr.interactee == src && Adjacent(usr))
					show_inv(usr)

	if(href_list["tie"])
		if(!usr.action_busy)
			if(MODE_HAS_TOGGLEABLE_FLAG(MODE_NO_STRIPDRAG_ENEMY) && (stat == DEAD || health < HEALTH_THRESHOLD_CRIT) && !get_target_lock(usr.faction_group))
				to_chat(usr, SPAN_WARNING("You can't strip a crit or dead member of another faction!"))
				return
			if(w_uniform && istype(w_uniform, /obj/item/clothing))
				var/obj/item/clothing/under/U = w_uniform
				if(!LAZYLEN(U.accessories))
					return FALSE
				var/obj/item/clothing/accessory/A = LAZYACCESS(U.accessories, 1)
				if(LAZYLEN(U.accessories) > 1)
					A = tgui_input_list(usr, "Select an accessory to remove from [U]", "Remove accessory", U.accessories)
				if(!istype(A))
					return
				attack_log += text("\[[time_stamp()]\] <font color='orange'>Has had their accessory ([A]) removed by [key_name(usr)]</font>")
				usr.attack_log += text("\[[time_stamp()]\] <font color='red'>Attempted to remove [key_name(src)]'s' accessory ([A])</font>")
				if(istype(A, /obj/item/clothing/accessory/holobadge) || istype(A, /obj/item/clothing/accessory/medal))
					visible_message(SPAN_DANGER("<B>[usr] tears off \the [A] from [src]'s [U]!</B>"), null, null, 5)
					if(U == w_uniform)
						U.remove_accessory(usr, A)
				else
					visible_message(SPAN_DANGER("<B>[usr] is trying to take off \a [A] from [src]'s [U]!</B>"), null, null, 5)
					if(do_after(usr, HUMAN_STRIP_DELAY, INTERRUPT_ALL, BUSY_ICON_GENERIC, src, INTERRUPT_MOVED, BUSY_ICON_GENERIC))
						if(U == w_uniform)
							U.remove_accessory(usr, A)

	if(href_list["sensor"])
		if(!usr.action_busy)
			if(MODE_HAS_TOGGLEABLE_FLAG(MODE_NO_STRIPDRAG_ENEMY) && (stat == DEAD || health < HEALTH_THRESHOLD_CRIT) && !get_target_lock(usr.faction_group))
				to_chat(usr, SPAN_WARNING("You can't tweak the sensors of a crit or dead member of another faction!"))
				return
			attack_log += text("\[[time_stamp()]\] <font color='orange'>Has had their sensors toggled by [key_name(usr)]</font>")
			usr.attack_log += text("\[[time_stamp()]\] <font color='red'>Attempted to toggle [key_name(src)]'s' sensors</font>")
			var/obj/item/clothing/under/U = w_uniform
			if(QDELETED(U))
				to_chat(usr, "You're not wearing a uniform!.")
			else if(U.has_sensor >= 2)
				to_chat(usr, "The controls are locked.")
			else
				var/oldsens = U.has_sensor
				visible_message(SPAN_DANGER("<B>[usr] is trying to modify [src]'s sensors!</B>"), null, null, 4)
				if(do_after(usr, HUMAN_STRIP_DELAY, INTERRUPT_ALL, BUSY_ICON_GENERIC, src, INTERRUPT_MOVED, BUSY_ICON_GENERIC))
					if(U == w_uniform)
						if(U.has_sensor >= 2)
							to_chat(usr, "The controls are locked.")
						else if(U.has_sensor == oldsens)
							U.set_sensors(usr)

	if (href_list["squadfireteam"])

		var/mob/living/carbon/human/target
		var/mob/living/carbon/human/sl
		if(href_list["squadfireteam_target"])
			sl = src
			for(var/mob/living/carbon/human/mar in sl.assigned_squad.marines_list)
				if(href_list["squadfireteam_target"] == "\ref[mar]")
					target = mar
					break
		else
			sl = usr
			target = src

		if(sl.is_mob_incapacitated() || !hasHUD(sl,"squadleader"))
			return

		if(!target || !target.assigned_squad || !target.assigned_squad.squad_leader || target.assigned_squad.squad_leader != sl)
			return

		if(target.squad_status == "K.I.A.")
			to_chat(sl, "[FONT_SIZE_BIG("<font color='red'>You can't assign K.I.A. marines to fireteams.</font>")]")
			return

		target.assigned_squad.manage_fireteams(target)

	if (href_list["squad_status"])
		var/mob/living/carbon/human/target
		for(var/mob/living/carbon/human/mar in assigned_squad.marines_list)
			if(href_list["squad_status_target"] == "\ref[mar]")
				target = mar
				break
		if(!istype(target))
			return

		if(is_mob_incapacitated() && !hasHUD(src,"squadleader"))
			return

		if(!target.assigned_squad || !target.assigned_squad.squad_leader || target.assigned_squad.squad_leader != src)
			return

		assigned_squad.change_squad_status(target)

	if(href_list["criminal"])
		if(hasHUD(usr,"security"))
			var/modified = 0
			var/perpref = null
			if(wear_id)
				var/obj/item/card/id/I = wear_id.GetID()
				if(I)
					perpref = I.registered_ref

			if(perpref)
				for(var/datum/data/record/E in GLOB.data_core.general)
					if(E.fields["ref"] == perpref)
						for(var/datum/data/record/R in GLOB.data_core.security)
							if(R.fields["id"] == E.fields["id"])

								var/setcriminal = tgui_input_list(usr, "Specify a new criminal status for this person.", "Security HUD", list("None", "*Arrest*", "Incarcerated", "Released", "Suspect", "NJP", "Cancel"))

								if(hasHUD(usr, "security"))
									if(setcriminal != "Cancel")
										R.fields["criminal"] = setcriminal
										modified = 1
										sec_hud_set_security_status()


			if(!modified)
				to_chat(usr, SPAN_DANGER("Unable to locate a data core entry for this person."))

	if(href_list["secrecord"])
		if(hasHUD(usr,"security"))
			var/perpref = null
			var/read = 0

			if(wear_id)
				var/obj/item/card/id/ID = wear_id.GetID()
				if(istype(ID))
					perpref = ID.registered_ref
			for(var/datum/data/record/E in GLOB.data_core.general)
				if(E.fields["ref"] == perpref)
					for(var/datum/data/record/R in GLOB.data_core.security)
						if(R.fields["id"] == E.fields["id"])
							if(hasHUD(usr,"security"))
								to_chat(usr, "<b>Name:</b> [R.fields["name"]]	<b>Criminal Status:</b> [R.fields["criminal"]]")
								to_chat(usr, "<b>Incidents:</b> [R.fields["incident"]]")
								to_chat(usr, "<a href='?src=\ref[src];secrecordComment=1'>\[View Comment Log\]</a>")
								read = 1

			if(!read)
				to_chat(usr, SPAN_DANGER("Unable to locate a data core entry for this person."))

	if(href_list["secrecordComment"] && hasHUD(usr,"security"))
		var/perpref = null
		if(wear_id)
			var/obj/item/card/id/ID = wear_id.GetID()
			if(istype(ID))
				perpref = ID.registered_ref

		var/read = 0

		if(perpref)
			for(var/datum/data/record/E in GLOB.data_core.general)
				if(E.fields["ref"] != perpref)
					continue
				for(var/datum/data/record/R in GLOB.data_core.security)
					if(R.fields["id"] != E.fields["id"])
						continue
					read = 1
					if(!islist(R.fields["comments"]))
						to_chat(usr, "<br /><b>No comments</b>")
						continue
					var/comment_markup = ""
					for(var/com_i in R.fields["comments"])
						var/comment = R.fields["comments"][com_i]
						comment_markup += text("<br /><b>[] / [] ([])</b><br />", comment["created_at"], comment["created_by"]["name"], comment["created_by"]["rank"])
						if (isnull(comment["deleted_by"]))
							comment_markup += text("[]<br />", comment["entry"])
							continue
						comment_markup += text("<i>Comment deleted by [] at []</i><br />", comment["deleted_by"], comment["deleted_at"])
					to_chat(usr, comment_markup)
					to_chat(usr, "<a href='?src=\ref[src];secrecordadd=1'>\[Add comment\]</a><br />")

		if(!read)
			to_chat(usr, SPAN_DANGER("Unable to locate a data core entry for this person."))

	if(href_list["secrecordadd"] && hasHUD(usr,"security"))
		var/perpref = null
		if(wear_id)
			var/obj/item/card/id/ID = wear_id.GetID()
			if(istype(ID))
				perpref = ID.registered_ref

		if(perpref)
			for(var/datum/data/record/E in GLOB.data_core.general)
				if(E.fields["ref"] != perpref)
					continue
				for(var/datum/data/record/R in GLOB.data_core.security)
					if(R.fields["id"] != E.fields["id"])
						continue
					var/t1 = copytext(trim(strip_html(input("Your name and time will be added to this new comment.", "Add a comment", null, null)  as message)), 1, MAX_MESSAGE_LEN)
					if(!(t1) || usr.stat || usr.is_mob_restrained())
						return
					var/created_at = text("[]&nbsp;&nbsp;[]&nbsp;&nbsp;[]", time2text(world.realtime, "MMM DD"), time2text(world.time, "[worldtime2text()]:ss"), game_year)
					var/new_comment = list("entry" = t1, "created_by" = list("name" = "", "rank" = ""), "deleted_by" = null, "deleted_at" = null, "created_at" = created_at)
					if(istype(usr,/mob/living/carbon/human))
						var/mob/living/carbon/human/U = usr
						new_comment["created_by"]["name"] = U.get_authentification_name()
						new_comment["created_by"]["rank"] = U.get_assignment()
					else if(istype(usr,/mob/living/silicon/robot))
						var/mob/living/silicon/robot/U = usr
						new_comment["created_by"]["name"] = U.name
						new_comment["created_by"]["rank"] = "[U.modtype] [U.braintype]"
					if(!islist(R.fields["comments"]))
						R.fields["comments"] = list("1" = new_comment)
					else
						var/new_com_i = length(R.fields["comments"]) + 1
						R.fields["comments"]["[new_com_i]"] = new_comment
					to_chat(usr, "You have added a new comment to the Security Record of [R.fields["name"]]. <a href='?src=\ref[src];secrecordComment=1'>\[View Comment Log\]</a>")

	if(href_list["medical"])
		if(hasHUD(usr,"medical"))
			var/perpref = null
			if(wear_id)
				var/obj/item/card/id/ID = wear_id.GetID()
				if(istype(ID))
					perpref = ID.registered_ref

			var/modified = FALSE

			if(perpref)
				for(var/datum/data/record/E in GLOB.data_core.general)
					if(E.fields["ref"] == perpref)
						for(var/datum/data/record/R in GLOB.data_core.general)
							if(R.fields["id"] == E.fields["id"])

								var/setmedical = tgui_input_list(usr, "Specify a new medical status for this person.", "Medical HUD", R.fields["p_stat"], list("*SSD*", "*Deceased*", "Physically Unfit", "Active", "Disabled", "Cancel"))

								if(hasHUD(usr,"medical"))
									if(setmedical != "Cancel")
										R.fields["p_stat"] = setmedical
										modified = 1

										spawn()
											if(istype(usr,/mob/living/carbon/human))
												var/mob/living/carbon/human/U = usr
												U.handle_regular_hud_updates()
											if(istype(usr,/mob/living/silicon/robot))
												var/mob/living/silicon/robot/U = usr
												U.handle_regular_hud_updates()

			if(!modified)
				to_chat(usr, SPAN_DANGER("Unable to locate a data core entry for this person."))

	if(href_list["medrecord"])
		if(hasHUD(usr,"medical"))
			var/perpref = null
			if(wear_id)
				var/obj/item/card/id/ID = wear_id.GetID()
				if(istype(ID))
					perpref = ID.registered_ref

			var/read = FALSE

			if(perpref)
				for(var/datum/data/record/E in GLOB.data_core.general)
					if(E.fields["ref"] == perpref)
						for(var/datum/data/record/R in GLOB.data_core.medical)
							if(R.fields["id"] == E.fields["id"])
								if(hasHUD(usr,"medical"))
									to_chat(usr, "<b>Name:</b> [R.fields["name"]]	<b>Blood Type:</b> [R.fields["b_type"]]")
									to_chat(usr, "<b>Minor Disabilities:</b> [R.fields["mi_dis"]]")
									to_chat(usr, "<b>Details:</b> [R.fields["mi_dis_d"]]")
									to_chat(usr, "<b>Major Disabilities:</b> [R.fields["ma_dis"]]")
									to_chat(usr, "<b>Details:</b> [R.fields["ma_dis_d"]]")
									to_chat(usr, "<b>Notes:</b> [R.fields["notes"]]")
									to_chat(usr, "<a href='?src=\ref[src];medrecordComment=1'>\[View Comment Log\]</a>")
									read = 1

			if(!read)
				to_chat(usr, SPAN_DANGER("Unable to locate a data core entry for this person."))

	if(href_list["medrecordComment"])
		if(hasHUD(usr,"medical"))
			var/perpref = null
			if(wear_id)
				var/obj/item/card/id/ID = wear_id.GetID()
				if(istype(ID))
					perpref = ID.registered_ref

			var/read = FALSE

			if(perpref)
				for(var/datum/data/record/E in GLOB.data_core.general)
					if(E.fields["ref"] == perpref)
						for(var/datum/data/record/R in GLOB.data_core.medical)
							if(R.fields["id"] == E.fields["id"])
								if(hasHUD(usr,"medical"))
									read = 1
									var/counter = 1
									while(R.fields["com_[counter]"])
										to_chat(usr, R.fields["com_[counter]"])
										counter++
									if(counter == 1)
										to_chat(usr, "No comment found")
									to_chat(usr, "<a href='?src=\ref[src];medrecordadd=1'>\[Add comment\]</a>")

			if(!read)
				to_chat(usr, SPAN_DANGER("Unable to locate a data core entry for this person."))

	if(href_list["medrecordadd"])
		if(hasHUD(usr,"medical"))
			var/perpref = null
			if(wear_id)
				var/obj/item/card/id/ID = wear_id.GetID()
				if(istype(ID))
					perpref = ID.registered_ref

			if(perpref)
				for(var/datum/data/record/E in GLOB.data_core.general)
					if(E.fields["ref"] == perpref)
						for(var/datum/data/record/R in GLOB.data_core.medical)
							if(R.fields["id"] == E.fields["id"])
								if(hasHUD(usr,"medical"))
									var/t1 = strip_html(input("Add Comment:", "Med. records", null, null)  as message)
									if(!(t1) || usr.stat || usr.is_mob_restrained() || !(hasHUD(usr,"medical")) )
										return
									var/counter = 1
									while(R.fields[text("com_[]", counter)])
										counter++
									if(istype(usr,/mob/living/carbon/human))
										var/mob/living/carbon/human/U = usr
										R.fields[text("com_[counter]")] = text("Made by [U.get_authentification_name()] ([U.get_assignment()]) on [time2text(world.realtime, "DDD MMM DD hh:mm:ss")], [game_year]<BR>[t1]")
									if(istype(usr,/mob/living/silicon/robot))
										var/mob/living/silicon/robot/U = usr
										R.fields[text("com_[counter]")] = text("Made by [U.name] ([U.modtype] [U.braintype]) on [time2text(world.realtime, "DDD MMM DD hh:mm:ss")], [game_year]<BR>[t1]")

	if(href_list["medholocard"])
		if(!skillcheck(usr, SKILL_MEDICAL, SKILL_MEDICAL_MEDIC))
			to_chat(usr, SPAN_WARNING("You're not trained to use this."))
			return
		if(!has_species(src, "Human"))
			to_chat(usr, SPAN_WARNING("Triage holocards only works on humans."))
			return
		var/newcolor = tgui_input_list(usr, "Choose a triage holo card to add to the patient:", "Triage holo card", list("black", "red", "orange", "none"))
		if(!newcolor) return
		if(get_dist(usr, src) > 7)
			to_chat(usr, SPAN_WARNING("[src] is too far away."))
			return
		if(newcolor == "none")
			if(!holo_card_color) return
			holo_card_color = null
			to_chat(usr, SPAN_NOTICE("You remove the holo card on [src]."))
		else if(newcolor != holo_card_color)
			holo_card_color = newcolor
			to_chat(usr, SPAN_NOTICE("You add a [newcolor] holo card on [src]."))
		update_targeted()

	if(href_list["scanreport"])
		if(hasHUD(usr,"medical"))
			if(!skillcheck(usr, SKILL_MEDICAL, SKILL_MEDICAL_MEDIC))
				to_chat(usr, SPAN_WARNING("You're not trained to use this."))
				return
			if(!has_species(src, "Human"))
				to_chat(usr, SPAN_WARNING("This only works on humans."))
				return
			if(get_dist(usr, src) > 7)
				to_chat(usr, SPAN_WARNING("[src] is too far away."))
				return

			var/me_ref = WEAKREF(src)
			for(var/datum/data/record/R in GLOB.data_core.medical)
				if(R.fields["ref"] == me_ref)
					if(R.fields["last_scan_time"] && R.fields["last_scan_result"])
						show_browser(usr, R.fields["last_scan_result"], "Medical Scan Report", "scanresults", "size=430x600")
					break

	if(href_list["lookitem"])
		var/obj/item/I = locate(href_list["lookitem"])
		if(istype(I))
			I.examine(usr)

	if(href_list["flavor_change"])
		if(usr.client != client)
			return

		switch(href_list["flavor_change"])
			if("done")
				close_browser(src, "flavor_changes")
				return
			if("general")
				var/msg = input(usr,"Update the general description of your character. This will be shown regardless of clothing, and may include OOC notes and preferences.","Flavor Text",html_decode(flavor_texts[href_list["flavor_change"]])) as message
				if(msg != null)
					msg = copytext(msg, 1, MAX_MESSAGE_LEN)
					msg = html_encode(msg)
				flavor_texts[href_list["flavor_change"]] = msg
				return
			else
				var/msg = input(usr,"Update the flavor text for your [href_list["flavor_change"]].","Flavor Text",html_decode(flavor_texts[href_list["flavor_change"]])) as message
				if(msg != null)
					msg = copytext(msg, 1, MAX_MESSAGE_LEN)
					msg = html_encode(msg)
				flavor_texts[href_list["flavor_change"]] = msg
				set_flavor()
				return

	if(href_list["limbitems"])
		var/list/found = list()
		var/msg = ""
		for(var/obj/limb/L in limbs)
			SEND_SIGNAL(L, COMSIG_LIMB_GET_ATTACHED_ITEMS, found)
			if(length(found))
				msg += "<b>[L.display_name]</b>\n"
				for(var/obj/item/I in found)
					msg += "\The [I.name] - <a href='?src=\ref[src];lookitem=\ref[I]'>\[Examine\]</a> <a href='?src=\ref[src];removelimbitem=\ref[I]'>\[Remove\] </a>\n"
				found.Cut()
		to_chat(usr, msg)

	if(href_list["removelimbitem"])
		var/mob/user = usr
		var/obj/item = locate(href_list["removelimbitem"])
		if(!istype(item.loc, /obj/limb))
			return
		var/obj/limb/L = item.loc

		var/action_time = HUMAN_LIMB_ITEM_REMOVAL_DELAY
		var/self_removal = (user == src)
		var/helper_item = user.get_active_hand()
		if(helper_item)
			if(HAS_TRAIT(user.get_active_hand(), TRAIT_PRECISE))
				action_time *= 0.5
		visible_message(SPAN_NOTICE("[user] begins to remove \an [item.name] from [self_removal ? "their" : "[src]'s"] [L.display_name]"),
						SPAN_NOTICE("[self_removal ? "You" : user] begin[self_removal ? "" : "s"] to remove \the [item.name] from your [L.display_name]"))
		if(do_after(user, action_time, INTERRUPT_ALL, BUSY_ICON_GENERIC))
			to_chat(user, SPAN_NOTICE("You succeed!"))
			item.forceMove(get_turf(src))
			SEND_SIGNAL(item, COMSIG_ITEM_REMOVED_FROM_LIMB, L)
	..()
	return

///get_eye_protection()
///Returns a number between -1 to 2
/mob/living/carbon/human/get_eye_protection()
	var/number = 0

	if(species && !species.has_organ["eyes"]) return 2//No eyes, can't hurt them.

	if(!internal_organs_by_name)
		return 2
	var/datum/internal_organ/eyes/I = internal_organs_by_name["eyes"]
	if(I)
		if(I.cut_away)
			return 2
		if(I.robotic == ORGAN_ROBOT)
			return 2
	else
		return 2

	if(istype(head, /obj/item/clothing))
		var/obj/item/clothing/C = head
		number += C.eye_protection
	if(istype(wear_mask))
		number += wear_mask.eye_protection
	if(glasses)
		number += glasses.eye_protection

	return number


/mob/living/carbon/human/abiotic(var/full_body = 0)
	if(full_body && ((l_hand && !( l_hand.flags_item & ITEM_ABSTRACT)) || (r_hand && !( r_hand.flags_item & ITEM_ABSTRACT)) || (back || wear_mask || head || shoes || w_uniform || wear_suit || glasses || wear_l_ear || wear_r_ear || gloves)))
		return TRUE

	if((l_hand && !(l_hand.flags_item & ITEM_ABSTRACT)) || (r_hand && !(r_hand.flags_item & ITEM_ABSTRACT)) )
		return TRUE

	return FALSE

/mob/living/carbon/human/get_species()
	if(!species)
		set_species()
	return species.name

/mob/living/carbon/human/proc/vomit()

	if(species.flags & IS_SYNTHETIC)
		return //Machines don't throw up.

	if(stat == 2) //Corpses don't puke
		return

	if(!lastpuke)
		lastpuke = 1
		to_chat(src, SPAN_WARNING("You feel nauseous..."))
		addtimer(CALLBACK(GLOBAL_PROC, .proc/to_chat, src, "You feel like you are about to throw up!"), 15 SECONDS)
		addtimer(CALLBACK(src, .proc/do_vomit), 25 SECONDS)

/mob/living/carbon/human/proc/do_vomit()
	Stun(5)
	if(stat == 2) //One last corpse check
		return
	src.visible_message(SPAN_WARNING("[src] throws up!"), SPAN_WARNING("You throw up!"), null, 5)
	playsound(loc, 'sound/effects/splat.ogg', 25, 1, 7)

	var/turf/location = loc
	if(istype(location, /turf))
		location.add_vomit_floor(src, 1)

	nutrition -= 40
	apply_damage(-3, TOX)
	addtimer(VARSET_CALLBACK(src, lastpuke, FALSE), 35 SECONDS)

/mob/living/carbon/human/proc/get_visible_gender()
	if(wear_suit && wear_suit.flags_inv_hide & HIDEJUMPSUIT && ((head && head.flags_inv_hide & HIDEMASK) || wear_mask))
		return NEUTER
	return gender

/mob/living/carbon/human/revive(keep_viruses)
	var/obj/limb/head/h = get_limb("head")
	if(QDELETED(h))
		h = get_limb("synthetic head")
	else
		h.disfigured = 0
	name = get_visible_name()

	if(species && !(species.flags & NO_BLOOD))
		restore_blood()

	//try to find the brain player in the decapitated head and put them back in control of the human
	if(!client && !mind) //if another player took control of the human, we don't want to kick them out.
		for(var/i in GLOB.head_limb_list)
			var/obj/item/limb/head/H = i
			if(!H.brainmob)
				continue
			if(H.brainmob.real_name != src.real_name)
				continue
			if(!H.brainmob.mind)
				continue
			H.brainmob.mind.transfer_to(src)
			qdel(H)

	if(!keep_viruses)
		for(var/datum/disease/virus in viruses)
			if(istype(virus, /datum/disease/black_goo))
				continue
			virus.cure(0)

	undefibbable = FALSE

	//Remove any larva.
	var/obj/item/alien_embryo/A = locate() in src
	if(A)
		var/mob/living/carbon/Xenomorph/Larva/L = locate() in src //if the larva was fully grown, ready to burst.
		if(L)
			qdel(L)
		qdel(A)
		status_flags &= ~XENO_HOST

	..()

/mob/living/carbon/human/get_visible_implants(var/class = 0)
	var/list/visible_objects = list()
	for(var/obj/item/W in embedded_items)
		if(!istype(W, /obj/item/shard/shrapnel))
			visible_objects += W
	return visible_objects


/mob/living/carbon/human/proc/handle_embedded_objects()
	if((stat == DEAD) || lying || buckled) // Shouldnt be needed, but better safe than sorry
		return

	for(var/obj/item/W in embedded_items)
		var/obj/limb/organ = W.embedded_organ
		// Check if shrapnel
		if(istype(W, /obj/item/shard/shrapnel))
			var/obj/item/shard/shrapnel/embedded = W
			embedded.on_embedded_movement(src)
		// Check if its a bladed weapon
		else if(W.sharp || W.edge)
			if(prob(20)) //Let's not make throwing knives too good in HvH
				organ.take_damage(rand(1,2), 0, 0)
		if(prob(30))	// Spam chat less
			to_chat(src, SPAN_HIGHDANGER("Your movement jostles [W] in your [organ.display_name] painfully."))

/mob/living/carbon/human/verb/check_status()
	set category = "Object"
	set name = "Check Status"
	set src in view(1)
	var/self = (usr == src)
	var/msg = ""


	if(usr.stat > 0 || usr.is_mob_restrained() || !ishuman(usr)) return

	if(self)
		var/list/wounded_limbs = list()
		for(var/limb_name in limb_wounds)
			if(length(limb_wounds[limb_name]))
				wounded_limbs += limb_name
		if(length(wounded_limbs))
			msg += "Your [english_list(wounded_limbs)] [length(wounded_limbs) > 1 ? "are" : "is"] broken\n"
	to_chat(usr,SPAN_NOTICE("You [self ? "take a moment to analyze yourself":"start analyzing [src]"]"))
	if(toxloss > 20)
		msg += "[self ? "Your" : "Their"] skin is slightly green\n"
	if(is_bleeding())
		msg += "[self ? "You" : "They"] have bleeding wounds on [self ? "your" : "their"] body\n"
	if(knocked_out && stat != DEAD)
		msg += "They seem to be unconscious\n"
	if(stat == DEAD)
		if(src.check_tod() && is_revivable())
			msg += "They're not breathing"
		else
			if(has_limb("head"))
				msg += "Their eyes have gone blank, there are no signs of life"
			else
				msg += "They are definitely dead"
	else
		msg += "[self ? "You're":"They're"] alive and breathing"


	to_chat(usr,SPAN_WARNING(msg))


/mob/living/carbon/human/verb/view_manifest()
	set name = "View Crew Manifest"
	set category = "IC"

	if(faction != FACTION_MARINE && !(faction in FACTION_LIST_WY))
		to_chat(usr, SPAN_WARNING("You have no access to [MAIN_SHIP_NAME] crew manifest."))
		return
	var/dat = GLOB.data_core.get_manifest()

	show_browser(src, dat, "Crew Manifest", "manifest", "size=400x750")

/mob/living/carbon/human/proc/set_species(var/new_species, var/default_colour)
	if(!new_species)
		new_species = "Human"

	if(species)
		if(species.name && species.name == new_species) //we're already that species.
			return

		// Clear out their species abilities.
		species.remove_inherent_verbs(src)

	var/datum/species/oldspecies = species

	species = GLOB.all_species[new_species]

	// If an invalid new_species value is passed, just default to human
	if (!istype(species))
		species = GLOB.all_species["Human"]

	if(oldspecies)
		//additional things to change when we're no longer that species
		oldspecies.post_species_loss(src)

	mob_flags = species.mob_flags
	for(var/T in species.mob_inherent_traits)
		ADD_TRAIT(src, T, TRAIT_SOURCE_SPECIES)

	species.create_organs(src)

	if(species.base_color && default_colour)
		//Apply colour.
		r_skin = hex2num(copytext(species.base_color,2,4))
		g_skin = hex2num(copytext(species.base_color,4,6))
		b_skin = hex2num(copytext(species.base_color,6,8))
	else
		r_skin = 0
		g_skin = 0
		b_skin = 0

	if(species.hair_color)
		r_hair = hex2num(copytext(species.hair_color, 2, 4))
		g_hair = hex2num(copytext(species.hair_color, 4, 6))
		b_hair = hex2num(copytext(species.hair_color, 6, 8))

	// Switches old pain and stamina over
	species.initialize_pain(src)
	species.initialize_stamina(src)
	species.handle_post_spawn(src)

	INVOKE_ASYNC(src, .proc/regenerate_icons)
	INVOKE_ASYNC(src, .proc/restore_blood)
	INVOKE_ASYNC(src, .proc/update_body, 1, 0)
	INVOKE_ASYNC(src, .proc/update_hair)
	if(!(species.flags & HAS_UNDERWEAR))
		INVOKE_ASYNC(src, .proc/remove_underwear)

	if(species)
		return TRUE
	else
		return FALSE


/mob/living/carbon/human/print_flavor_text()
	var/list/equipment = list(src.head,src.wear_mask,src.glasses,src.w_uniform,src.wear_suit,src.gloves,src.shoes)
	var/head_exposed = 1
	var/face_exposed = 1
	var/eyes_exposed = 1
	var/torso_exposed = 1
	var/arms_exposed = 1
	var/legs_exposed = 1
	var/hands_exposed = 1
	var/feet_exposed = 1

	for(var/obj/item/clothing/C in equipment)
		if(C.flags_armor_protection & BODY_FLAG_HEAD)
			head_exposed = 0
		if(C.flags_armor_protection & BODY_FLAG_FACE)
			face_exposed = 0
		if(C.flags_armor_protection & BODY_FLAG_EYES)
			eyes_exposed = 0
		if(C.flags_armor_protection & BODY_FLAG_CHEST)
			torso_exposed = 0
		if(C.flags_armor_protection & BODY_FLAG_ARMS)
			arms_exposed = 0
		if(C.flags_armor_protection & BODY_FLAG_HANDS)
			hands_exposed = 0
		if(C.flags_armor_protection & BODY_FLAG_LEGS)
			legs_exposed = 0
		if(C.flags_armor_protection & BODY_FLAG_FEET)
			feet_exposed = 0

	flavor_text = flavor_texts["general"]
	flavor_text += "\n\n"
	for(var/T in flavor_texts)
		if(flavor_texts[T] && flavor_texts[T] != "")
			if((T == "head" && head_exposed) || (T == "face" && face_exposed) || (T == "eyes" && eyes_exposed) || (T == "torso" && torso_exposed) || (T == "arms" && arms_exposed) || (T == "hands" && hands_exposed) || (T == "legs" && legs_exposed) || (T == "feet" && feet_exposed))
				flavor_text += flavor_texts[T]
				flavor_text += "\n\n"
	return ..()



/mob/living/carbon/human/proc/vomit_on_floor()
	var/turf/T = get_turf(src)
	visible_message(SPAN_DANGER("[src] vomits on the floor!"), null, null, 5)
	nutrition -= 20
	apply_damage(-3, TOX)
	playsound(T, 'sound/effects/splat.ogg', 25, 1, 7)
	T.add_vomit_floor(src)

/mob/living/carbon/human/slip(slip_source_name, stun_level, weaken_level, run_only, override_noslip, slide_steps)
	if(shoes && !override_noslip) // && (shoes.flags_inventory & NOSLIPPING)) // no more slipping if you have shoes on. -spookydonut
		return FALSE
	. = ..()



//very similar to xeno's queen_locator() but this is for locating squad leader.
/mob/living/carbon/human/proc/locate_squad_leader(var/tracker_setting = TRACKER_SL)
	if(!assigned_squad) return

	var/mob/living/carbon/human/H
	var/tl_prefix = ""
	if(hud_used)
		hud_used.locate_leader.icon_state = "trackoff"


	if(tracker_setting == TRACKER_SL) //default
		H = assigned_squad.squad_leader
	else if(tracker_setting == TRACKER_LZ)
		var/obj/structure/machinery/computer/shuttle_control/C = SSticker.mode.active_lz
		if(!C) //no LZ selected
			hud_used.locate_leader.icon_state = "trackoff"
		else if(C.z != src.z || get_dist(src,C) < 1)
			hud_used.locate_leader.icon_state = "trackondirect_lz"
		else
			hud_used.locate_leader.setDir(get_dir(src,C))
			hud_used.locate_leader.icon_state = "trackon_lz"
		return
	else if(tracker_setting == TRACKER_FTL && src.assigned_fireteam)
		H = assigned_squad.fireteam_leaders[assigned_fireteam]
		tl_prefix = "_tl"
	if(!H)
		return
	if(H.z != src.z || get_dist(src,H) < 1 || src == H)
		hud_used.locate_leader.icon_state = "trackondirect[tl_prefix]"
	else
		hud_used.locate_leader.setDir(get_dir(src,H))
		hud_used.locate_leader.icon_state = "trackon[tl_prefix]"
	return



/mob/living/carbon/proc/locate_nearest_nuke()
	if(!bomb_set) return
	var/obj/structure/machinery/nuclearbomb/N
	for(var/obj/structure/machinery/nuclearbomb/bomb in world)
		if(!istype(N) || N.z != src.z )
			N = bomb
		if(bomb.z == src.z && get_dist(src,bomb) < get_dist(src,N))
			N = bomb
	if(N.z != src.z || !N)
		hud_used.locate_nuke.icon_state = "trackoff"
		return

	if(get_dist(src,N) < 1)
		hud_used.locate_nuke.icon_state = "nuke_trackondirect"
	else
		hud_used.locate_nuke.setDir(get_dir(src,N))
		hud_used.locate_nuke.icon_state = "nuke_trackon"




/mob/proc/update_sight()
	return

/mob/living/carbon/human/update_sight()
	if(SEND_SIGNAL(src, COMSIG_HUMAN_UPDATE_SIGHT) & COMPONENT_OVERRIDE_UPDATE_SIGHT) return

	sight &= ~BLIND // Never have blind on by default

	if(stat == DEAD)
		sight |= (SEE_TURFS|SEE_MOBS|SEE_OBJS)
		see_in_dark = 8
		see_invisible = SEE_INVISIBLE_LEVEL_TWO
	else
		if(!(SEND_SIGNAL(src, COMSIG_MOB_PRE_GLASSES_SIGHT_BONUS) & COMPONENT_BLOCK_GLASSES_SIGHT_BONUS))
			sight &= ~(SEE_TURFS|SEE_MOBS|SEE_OBJS)
			see_in_dark = species.darksight
			see_invisible = see_in_dark > 2 ? SEE_INVISIBLE_LEVEL_ONE : SEE_INVISIBLE_LIVING
			if(glasses)
				process_glasses(glasses)
			else
				see_invisible = SEE_INVISIBLE_LIVING

	SEND_SIGNAL(src, COMSIG_HUMAN_POST_UPDATE_SIGHT)



/mob/proc/update_tint()

/mob/living/carbon/human/update_tint()
	var/tint_level = VISION_IMPAIR_NONE

	if(head && head.vision_impair)
		tint_level += head.vision_impair

	if(glasses && glasses.vision_impair)
		tint_level += glasses.vision_impair

	if(wear_mask && wear_mask.vision_impair)
		tint_level += wear_mask.vision_impair

	if(tint_level > VISION_IMPAIR_STRONG)
		tint_level = VISION_IMPAIR_STRONG

	if(tint_level)
		overlay_fullscreen("tint", /obj/screen/fullscreen/impaired, tint_level)
		return TRUE
	else
		clear_fullscreen("tint", 0)
		return FALSE


/mob/proc/update_glass_vision(obj/item/clothing/glasses/G)
	return

/mob/living/carbon/human/update_glass_vision(obj/item/clothing/glasses/G)
	if(G.fullscreen_vision)
		if(G == glasses && G.active) //equipped and activated
			overlay_fullscreen("glasses_vision", G.fullscreen_vision)
			return TRUE
		else //unequipped or deactivated
			clear_fullscreen("glasses_vision", 0)

/mob/living/carbon/human/verb/checkSkills()
	set name = "Check Skills"
	set category = "IC"
	set src = usr

	var/dat
	if(!usr || !usr.skills)
		dat += "NULL<br/>"
	else
		dat += "CQC: [usr.skills.get_skill_level(SKILL_CQC)]<br/>"
		dat += "Melee: [usr.skills.get_skill_level(SKILL_MELEE_WEAPONS)]<br/>"
		dat += "Firearms: [usr.skills.get_skill_level(SKILL_FIREARMS)]<br/>"
		dat += "Specialist Weapons: [usr.skills.get_skill_level(SKILL_SPEC_WEAPONS)]<br/>"
		dat += "Endurance: [usr.skills.get_skill_level(SKILL_ENDURANCE)]<br/>"
		dat += "Engineer: [usr.skills.get_skill_level(SKILL_ENGINEER)]<br/>"
		dat += "Construction: [usr.skills.get_skill_level(SKILL_CONSTRUCTION)]<br/>"
		dat += "Leadership: [usr.skills.get_skill_level(SKILL_LEADERSHIP)]<br/>"
		dat += "Medical: [usr.skills.get_skill_level(SKILL_MEDICAL)]<br/>"
		dat += "Surgery: [usr.skills.get_skill_level(SKILL_SURGERY)]<br/>"
		dat += "Research: [usr.skills.get_skill_level(SKILL_RESEARCH)]<br/>"
		dat += "Pilot: [usr.skills.get_skill_level(SKILL_PILOT)]<br/>"
		dat += "Police: [usr.skills.get_skill_level(SKILL_POLICE)]<br/>"
		dat += "Powerloader: [usr.skills.get_skill_level(SKILL_POWERLOADER)]<br/>"
		dat += "Vehicles: [usr.skills.get_skill_level(SKILL_VEHICLE)]<br/>"
		dat += "JTAC: [usr.skills.get_skill_level(SKILL_JTAC)]<br/>"

	show_browser(src, dat, "Skills", "checkskills")
	return

/mob/living/carbon/human/yautja/Initialize(mapload)
	. = ..(mapload, new_species = "Yautja")

/mob/living/carbon/human/monkey/Initialize(mapload)
	. = ..(mapload, new_species = "Monkey")


/mob/living/carbon/human/farwa/Initialize(mapload)
	. = ..(mapload, new_species = "Farwa")


/mob/living/carbon/human/neaera/Initialize(mapload)
	. = ..(mapload, new_species = "Neaera")

/mob/living/carbon/human/stok/Initialize(mapload)
	. = ..(mapload, new_species = "Stok")

/mob/living/carbon/human/yiren/Initialize(mapload)
	. = ..(mapload, new_species = "Yiren")

/mob/living/carbon/human/synthetic/Initialize(mapload)
	. = ..(mapload, "Synthetic")

/mob/living/carbon/human/synthetic/old/Initialize(mapload)
	. = ..(mapload, SYNTH_COLONY)

/mob/living/carbon/human/synthetic/combat/Initialize(mapload)
	. = ..(mapload, SYNTH_COMBAT)

/mob/living/carbon/human/synthetic/first/Initialize(mapload)
	. = ..(mapload, SYNTH_GEN_ONE)

/mob/living/carbon/human/synthetic/second/Initialize(mapload)
	. = ..(mapload, SYNTH_GEN_TWO)

/mob/living/carbon/human/synthetic/third/Initialize(mapload)
	. = ..(mapload, SYNTH_GEN_THREE)


/mob/living/carbon/human/resist_fire()
	if(isYautja(src))
		adjust_fire_stacks(HUNTER_FIRE_RESIST_AMOUNT, min_stacks = 0)
		KnockDown(1, TRUE) // actually 0.5
		spin(5, 1)
		visible_message(SPAN_DANGER("[src] expertly rolls on the floor, greatly reducing the amount of flames!"), \
			SPAN_NOTICE("You expertly roll to extinguish the flames!"), null, 5)
	else
		adjust_fire_stacks(HUMAN_FIRE_RESIST_AMOUNT, min_stacks = 0)
		KnockDown(4, TRUE)
		spin(35, 2)
		visible_message(SPAN_DANGER("[src] rolls on the floor, trying to put themselves out!"), \
			SPAN_NOTICE("You stop, drop, and roll!"), null, 5)

	if(istype(get_turf(src), /turf/open/gm/river))
		ExtinguishMob()

	if(fire_stacks > 0)
		return

	visible_message(SPAN_DANGER("[src] has successfully extinguished themselves!"), \
			SPAN_NOTICE("You extinguish yourself."), null, 5)

/mob/living/carbon/human/resist_acid()
	var/sleep_amount = 1
	if(isYautja(src))
		KnockDown(1, TRUE)
		spin(10, 2)
		visible_message(SPAN_DANGER("[src] expertly rolls on the floor!"), \
			SPAN_NOTICE("You expertly roll to get rid of the acid!"), null, 5)
	else
		KnockDown(1.5, TRUE)
		spin(15, 2)
		visible_message(SPAN_DANGER("[src] rolls on the floor, trying to get the acid off!"), \
			SPAN_NOTICE("You stop, drop, and roll!"), null, 5)

	sleep(sleep_amount)

	visible_message(SPAN_DANGER("[src] has successfully removed the acid!"), \
			SPAN_NOTICE("You get rid of the acid."), null, 5)
	extinguish_acid()
	return

/mob/living/carbon/human/resist_restraints()
	var/restraint
	var/breakouttime
	if(handcuffed)
		restraint = handcuffed
		breakouttime = handcuffed.breakouttime
	else if(legcuffed)
		restraint = legcuffed
		breakouttime = legcuffed.breakouttime
	else
		return

	next_move = world.time + 100
	last_special = world.time + 10
	var/can_break_cuffs
	if(iszombie(src))
		visible_message(SPAN_DANGER("[src] is attempting to break out of [restraint]..."), \
		SPAN_NOTICE("You use your superior zombie strength to start breaking [restraint]..."))
		if(!do_after(src, 100, INTERRUPT_NO_NEEDHAND^INTERRUPT_RESIST, BUSY_ICON_HOSTILE))
			return

		if(!restraint || buckled)
			return
		visible_message(SPAN_DANGER("[src] tears [restraint] in half!"), \
			SPAN_NOTICE("You tear [restraint] in half!"))
		restraint = null
		if(handcuffed)
			QDEL_NULL(handcuffed)
			handcuff_update()
		else
			QDEL_NULL(legcuffed)
			handcuff_update()
		return
	if(species.can_shred(src))
		can_break_cuffs = TRUE
	if(can_break_cuffs) //Don't want to do a lot of logic gating here.
		to_chat(usr, SPAN_DANGER("You attempt to break [restraint]. (This will take around 5 seconds and you need to stand still)"))
		for(var/mob/O in viewers(src))
			O.show_message(SPAN_DANGER("<B>[src] is trying to break [restraint]!</B>"), 1)
		if(!do_after(src, 50, INTERRUPT_NO_NEEDHAND^INTERRUPT_RESIST, BUSY_ICON_HOSTILE))
			return

		if(!restraint || buckled)
			return
		for(var/mob/O in viewers(src))
			O.show_message(SPAN_DANGER("<B>[src] manages to break [restraint]!</B>"), 1)
		to_chat(src, SPAN_WARNING("You successfully break [restraint]."))
		say(pick(";RAAAAAAAARGH!", ";HNNNNNNNNNGGGGGGH!", ";GWAAAAAAAARRRHHH!", "NNNNNNNNGGGGGGGGHH!", ";AAAAAAARRRGH!" ))
		if(handcuffed)
			QDEL_NULL(handcuffed)
			handcuff_update()
		else
			QDEL_NULL(legcuffed)
			handcuff_update()
	else
		var/displaytime = max(1, round(breakouttime / 600)) //Minutes
		to_chat(src, SPAN_WARNING("You attempt to remove [restraint]. (This will take around [displaytime] minute(s) and you need to stand still)"))
		for(var/mob/O in viewers(src))
			O.show_message(SPAN_DANGER("<B>[usr] attempts to remove [restraint]!</B>"), 1)
		if(!do_after(src, breakouttime, INTERRUPT_NO_NEEDHAND^INTERRUPT_RESIST, BUSY_ICON_HOSTILE))
			return

		if(!restraint || buckled)
			return // time leniency for lag which also might make this whole thing pointless but the server
		for(var/mob/O in viewers(src))//                                         lags so hard that 40s isn't lenient enough - Quarxink
			O.show_message(SPAN_DANGER("<B>[src] manages to remove [restraint]!</B>"), 1)
		to_chat(src, SPAN_NOTICE(" You successfully remove [restraint]."))
		drop_inv_item_on_ground(restraint)

/mob/living/carbon/human/equip_to_appropriate_slot(obj/item/W, ignore_delay = 1, var/list/slot_equipment_priority)
	if(species)
		slot_equipment_priority = species.slot_equipment_priority
	return ..(W,ignore_delay,slot_equipment_priority)

/mob/living/carbon/human/get_vv_options()
	. = ..()
	. += "<option value>-----HUMAN-----</option>"
	. += "<option value='?_src_=vars;edit_skill=\ref[src]'>Edit Skills</option>"
	. += "<option value='?_src_=vars;setspecies=\ref[src]'>Set Species</option>"
	. += "<option value='?_src_=vars;selectequipment=\ref[src]'>Select Equipment</option>"
	. += "<option value='?_src_=admin_holder;adminspawncookie=\ref[src]'>Give Cookie</option>"

/mob/living/carbon/human/update_can_stand()
	var/prev_state = can_stand
	var/left_side_tally = 0
	var/right_side_tally = 0
	var/left_side_support = FALSE
	var/right_side_support = FALSE

	var/additional_support = HAS_TRAIT(src, TRAIT_ADDITIONAL_STAND_SUPPORT)

	for(var/obj/limb/L as anything in limbs)
		if(!HAS_TRAIT(L, TRAIT_LIMB_ALLOWS_STAND) || L.status & LIMB_DESTROYED)
			continue
		if(L.body_side == LEFT)
			left_side_tally++
		else
			right_side_tally++

	//Check for side-specific additional support if there are no limbs to hold us up
	if(left_side_tally > 0)
		left_side_support = TRUE
	else
		if(l_hand)
			if(HAS_TRAIT(l_hand, TRAIT_CRUTCH))
				left_side_support = TRUE
	if(right_side_tally)
		right_side_support = TRUE
	else
		if(r_hand)
			if(HAS_TRAIT(r_hand, TRAIT_CRUTCH))
				right_side_support = TRUE

	//Both sides supporting? One must be a limb (no holding two crutches)
	if(left_side_support && right_side_support && (left_side_tally || right_side_tally))
		can_stand = TRUE
	else
		if((left_side_support || right_side_support) && (HAS_TRAIT(src, TRAIT_EXTREME_BODY_BALANCE) || additional_support))
			//One side supported + additional support == can stand
			can_stand = TRUE
		else
			can_stand = FALSE

	if(prev_state != can_stand)
		if(!can_stand)
			to_chat(src, SPAN_DANGER("Your legs can't hold you up any longer!"))
		update_canmove()
