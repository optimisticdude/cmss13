//Skills

/datum/skills/honor_guard
	name = "Honor Guard" //MP
	skills = list(
		SKILL_VEHICLE = SKILL_VEHICLE_CREWMAN,
		SKILL_POWERLOADER = SKILL_POWERLOADER_MASTER,
		SKILL_CQC = SKILL_CQC_SKILLED,
		SKILL_MEDICAL = SKILL_MEDICAL_TRAINED,
		SKILL_FIREARMS = SKILL_FIREARMS_TRAINED
	)

/datum/skills/honor_guard/vet
	name = "Honor Guard Verteran" //SO
	skills = list(
		SKILL_VEHICLE = SKILL_VEHICLE_CREWMAN,
		SKILL_POWERLOADER = SKILL_POWERLOADER_MASTER,
		SKILL_MEDICAL = SKILL_MEDICAL_TRAINED,
		SKILL_LEADERSHIP = SKILL_LEAD_EXPERT
	)

/datum/skills/honor_guard/spec
	name = "Honor Guard Weapons Specialist" //Tank crew
	skills = list(
		SKILL_VEHICLE = SKILL_VEHICLE_CREWMAN,
		SKILL_POWERLOADER = SKILL_POWERLOADER_MASTER,
		SKILL_LEADERSHIP = SKILL_LEAD_TRAINED,
		SKILL_MEDICAL = SKILL_MEDICAL_TRAINED,
		SKILL_SPEC_WEAPONS = SKILL_SPEC_ALL
	)

/datum/skills/honor_guard/lead
	name = "Honor Guard Squad Leader"
	skills = list(
		SKILL_ENGINEER = SKILL_ENGINEER_ENGI, //to fix CIC apc.
		SKILL_CONSTRUCTION = SKILL_CONSTRUCTION_ENGI,
		SKILL_LEADERSHIP = SKILL_LEAD_MASTER,
		SKILL_MEDICAL = SKILL_MEDICAL_MEDIC,
		SKILL_POLICE = SKILL_POLICE_FLASH,
		SKILL_POWERLOADER = SKILL_POWERLOADER_MASTER,
		SKILL_SPEC_WEAPONS = SKILL_SPEC_SMARTGUN,
	)

/datum/skills/mortar_crew
	name = "Mortar Crew"
	skills = list(
		SKILL_ENGINEER = SKILL_ENGINEER_ENGI,
		SKILL_CONSTRUCTION = SKILL_CONSTRUCTION_ENGI,
		SKILL_LEADERSHIP = SKILL_LEAD_BEGINNER,
		SKILL_POWERLOADER = SKILL_POWERLOADER_MASTER
	)