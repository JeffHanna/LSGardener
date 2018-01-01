/*
	LSGardener.ms
	v 1.91
	Created On: March 28, 2002
	Modified On: December 31, 2017
	Modified By: Jeff Hanna
	tested using 3ds Max 4.26 and 3ds Max 2018
	Based on SimpleScatter.ms and Planter.ms by Neil Blevins (soulburn@blur.com)
*/

(
	/*Globals*/

	global perform_scatter
	global perform_plant
	global geometryFilter
	global getSceneBbox

	global LSG_floater
	global scatter_rollout
	global plant_rollout
	global progress_rollout


	/*Includes*/


	/*Variables*/
	LSG_Version = "version 1.91"
	LSG_Date = "December 31, 2017"
	LSG_Time = "06:00:45 PM"

	area_obj = #()
	ground_obj = #()
	scattered_objects = #()
	holding_array = #()

	scatter_duplicates = 50

	min_scale = 75
	max_scale = 200

	intr_amnt = 0

	min_x = 0.00
	min_y = 0.00
	max_x = 0.00
	max_y = 0.00

	nu_scale = false
	building_transform = false


	/*Functions*/
	fn geometryFilter o =
	(
		superClassOf o == GeometryClass
	)


	fn getSceneBbox =
	(
		onwhat = $*
		if onwhat.count == 0 then return #([0,0,0],[0,0,0])
		else
		(
			max = [onwhat[1].max.x,onwhat[1].max.y,onwhat[1].max.z]
			min = [onwhat[1].min.x,onwhat[1].min.y,onwhat[1].min.z]
			for i in onwhat do
			(
				if superclassof i != light and superclassof i != camera and superclassof i != spacewarpObject then
				(
					if i.max.z > max.z then max.z = i.max.z
					if i.min.z < min.z then min.z = i.min.z
				)
			)
			return #([0,0,max.z],[0,0,min.z])
		)
	)


	fn performScatter =
	undo "Scatter" on
	(
		(
			/*Set and/or clear variables*/
			holding_array = #()
			scatter_items = #()

			sc_errors = 0
			scattered_count = 0
			iteration_count = 0
			total_tries = 1000
			overlap = 0

			z_pos = (getSceneBbox())[1].z + 100

			min_scale = min_scale as float
			max_scale = max_scale as float

			add_item = true


			/*Set the intrustion amount to at least 1 (to prevent divide by 0 errors). If the user is scattering builings set 
			the intrustion amount to 2*/
			if intr_amnt == 0 or intr_amnt == 1 then
			(
				intr_amnt = 1.0
			)
			else
			(
				intr_amnt = (intr_amnt as float) / 100
			)

			if building_transform == true then
			(
				intr_amnt = 2.0
			)


			/*Clear out the scatter_objects array between successive scatter runs*/
			for i = 1 to scattered_objects.count do
			(
				deleteItem scattered_objects 1
			)


			/*Put selected objects in a temporary array. Then traverse that array for GroupHead nodes and transfer those 
			to the scatter_items array*/
			for i in selection do
			(
				append holding_array i
			)

			for i = 1 to holding_array.count do
			(
				if isGroupMember holding_array[i] == false then
				(
					append scatter_items holding_array[i]
				)
			)

			
			abort = false

			for i = 1 to scatter_duplicates do
			(
				if abort == true then
				(
					exit
				)

				status_value = ((i as float)/(scatter_duplicates as float))*100

				nn = #()
				maxops_hack = #()
				si_val = random 1 scatter_items.count
				maxops.cloneNodes #(scatter_items[si_val]) newNodes:&nn

				for j = 1 to nn.count do
				(
					nn[j].transform.controller = copy nn[j].transform.controller /*break off from the instanced tranform controllers since maxops.CloneNodes only instances them*/
					if isGroupMember nn[j] == false then
					(
						append maxops_hack nn[j]
					)
				)
				m = maxops_hack[1]
				

				/*Lock random rotations to 90 deg intervals if scattering buildings..Otherwise, allow full 360 random rotation*/
				if building_transform == true then
				(
					rotate_val = ((random -4 4)*90)
				)
				else
				(
					rotate_val = random -180 180
				)
				rotate m rotate_val [0,0,1]


				/*Scale the object randomly (within the scale range the user selected on all three axes if the non-uniform 
				scale option is set.
				Otherwise, scale the object uniformly using a random value in the range of scale the user selected*/
				if nu_scale == true then
				(
					scale_val_x = random (min_scale/50) (max_scale/100)
					scale_val_y = random (min_scale/50) (max_scale/100)
					scale_val_z = random (min_scale/50) (max_scale/100)

					scale m [scale_val_x, scale_val_y, scale_val_z]
				)
				else
				(
					scale_val = random (min_scale/100) (max_scale/100)

					m.scale *= scale_val
				)


				/*Find a suitable place to place the first cloned object*/
				if scattered_objects.count == 0 then
				(
					missed_intersection = true
					do
					(
						ray_origin = [(random min_x max_x), (random min_y max_y), z_pos]
						s = intersectRay area_obj (ray ray_origin [0,0,-1])

						if s == undefined then
						(
							sc_errors += 1
						)
						else
						(
							m.pos.x = ray_origin.x
							m.pos.y = ray_origin.y
							scattered_count +=1
							missed_intersection = false
						)
					)
					while missed_intersection
				)
				else	/*Now find suitable places for the n remaining cloned objects.*/
				(
					missed_intersection = true
					do
					(
	 					iteration_count += 1
						ray_origin = [(random min_x max_x), (random min_y max_y), z_pos]
						ray_intersect = intersectRay area_obj (ray ray_origin [0,0,-1])

						if ray_intersect == undefined then
						(
							sc_errors += 1
						)
						else
						(
							too_close = 0
							for j = 1 to scattered_objects.count do
							(
								ray_origin_pt2 = [ray_origin.x, ray_origin.y]
								n = scattered_objects[j]

								scattered_objects_pt3 = n.pos

								scattered_objects_pt2 = [scattered_objects_pt3.x, scattered_objects_pt3.y]
								m_width = (((m.max.x - m.pos.x) * intr_amnt) + (n.max.x - n.pos.x))
								dist = (distance ray_origin_pt2 scattered_objects_pt2)

								if dist < m_width then
								(
									too_close += 1
								)
							)

							if too_close == 0 then
							(
								m.pos.x = ray_origin.x
								m.pos.y = ray_origin.y
								scattered_count += 1
								forceCompleteRedraw()
								missed_intersection = false
							)
							else
							(
								total_tries = ((total_tries - (too_close * .50)) as integer)
							)
						)

						if iteration_count >= total_tries then
						(
							error_message = "Cannot fit any more objects into the scatter area.\n" + scattered_count as string + " of " + scatter_duplicates as string + " items were scattered."
							messagebox error_message title:"LSGardener"
							add_item = false
							abort = true
							missed_intersection = false
						)
					)
					while missed_intersection
				)

				if add_item == true then
				(
					append scattered_objects m
				)
				else
				(
					delete m
				)

				iteration_count = 0

				progress_rollout.progress_bar.value = status_value
				forceCompleteRedraw()
			)
			select scattered_objects
			progress_rollout.progress_bar.value = 0
		)
	)


	fn performPlant =
	undo "Plant" on
	(
		(
			
			/* Set and/or clear local function variables*/
			pl_errors = 0

			high_z = (getSceneBbox())[1].z + 100
			low_z = (getSceneBbox())[2].z - 100
			local ray_origin
			local s

			for i in selection do
			(
				append scattered_objects i
			)
			
			/*Take the scattered objects and plant them on the terrain*/
			for i = 1 to scattered_objects.count do
			(
				status_value = ((i as float)/(scattered_objects.count as float))*100 /*initialize the progress bar*/

				/*cast a ray from the object's pivot point straight down. Assign the intersect coordinates to the variable 's'*/
				ray_origin = [scattered_objects[i].pos.x, scattered_objects[i].pos.y, high_z]
				s = intersectray ground_obj (ray ray_origin [0,0,-1])

				
				if s == undefined then /*if the ray misses then increment the placement error counter*/
				(
					pl_errors += 1
				)
				else /*if the ray hits move the selected object down to that point*/
				(
					scattered_objects[i].pos = s.pos
				)
				progress_rollout.progress_bar.value = status_value /*update the progress bar*/
				redrawViews()
			)
			progress_rollout.progress_bar.value = 0 /*when the function is finished clear the progress bar*/

			/*if objects weren't successfully planted tell the user how many errors were generated*/
			if pl_errors > 0 then
			(
				to_print = (pl_errors as string) + " object(s) in your selection were not directly above or below the ground object, and their positions were not modified"
				messagebox to_print title:"LSPlanter"
			)
		)
	)
	
	
	fn InstanceLocator = 
	(
		file_path = getSaveFileName caption:"File Save" types:"XML Files (*.xml)|*.xml|All Files (*.*)|*.*|"
		output_file = createFile file_path
		
		format "<Stage>\n" to:output_file
		
		for i = 1 to selection.count do
		(
			status_value = ((i as float)/(selection.count as float))*100 /*initialize the progress bar*/
			test_string = substring selection[i].name 1 3
			if test_string != "LOD" or tests != "ele" then
			(
				full_name = selection[i].name as string
				str_length = full_name.count as integer
				str_length = (str_length - 3)
				obj_name = substring full_name 1 str_length
				
				format "\t<Element>\n\t\t<Name>%</Name>\n\t\t<Type>16777216</Type>\n" obj_name to:output_file
				format "\t\t<Location>\n\t\t\t<X>%</X>\n\t\t\t<Y>%</Y>\n\t\t\t<Z>%</Z>\n\t\t</Location>\n" selection[i].pos.x selection[i].pos.y selection[i].pos.z to:output_file
				format "\t\t<Rotation>\n\t\t\t<W>%</W>\n\t\t\t<X>%</X>\n\t\t\t<Y>%</Y>\n\t\t\t<Z>%</Z>\n\t\t</Rotation>\n" selection[i].rotation.w selection[i].rotation.x selection[i].rotation.y selection[i].rotation.z to:output_file
				format "\t\t<Scale>%</Scale>\n\t</Element>\n" selection[i].scale.x to:output_file
				
				progress_rollout.progress_bar.value = status_value
			)
		)

		format "</Stage>\n" to:output_file
		
		close output_file
		progress_rollout.progress_bar.value = 0 /*when the function is finished clear the progress bar*/
	)	
	
	
	/*Rollouts*/
	rollout scatter_rollout "Scatter"
	(
		label lbl_num_dups "Duplicates:" align:#left across:2
		spinner num_dups "" fieldWidth:50 range:[1,99999,scatter_duplicates] type:#integer

		checkbox ck_building_transform "Scattering Buildings"

		slider sld_min_scale "Minimum Scale" width:150 height:44 range:[1,100,min_scale] enabled:true orient:#horizontal ticks:15 type:#integer align:#left across:2
		label lbl_min_scale "75%" align:#right

		slider sld_max_scale "Maximum Scale" width:150 height:44 range:[100,300,max_scale] enabled:true orient:#horizontal ticks:20 type:#integer align:#left across:2
		label lbl_max_scale "200%" align:#right

		checkbox ck_axis_scale "Non-Uniform Scale"

		slider sld_intr_amnt "Intrusion Amount" width:150 height:44 range:[0,50,intr_amnt] enabled:true orient:#horizontal ticks:25 type:#integer align:#left across:2

		label lbl_intr_amnt "0%" align:#right

		label lbl_area "Target Area:" align:#left across:2
		label lbl_what_area "None" align:#right

		pickbutton pick_scatter_area "Pick the Scatter Area" width:150 toolTip:"Pick The Scatter Area" align:#center

		button do_scatter "Scatter" width:150 height:40 toolTip:"Scatter" enabled:false align:#center

		button select_scatter "Select Scattered Items" width:150 toolTip:"Select Previous Scatter" enabled:false align:#left across:1
		button delete_scatter "Delete Scattered Items" width:150 toolTip:"Delete Previous Scatter" enabled:false align:#left

		on num_dups changed val do scatter_duplicates = val

		on ck_building_transform changed state do
		(
			if ck_building_transform.checked == true then
			(
				building_transform = true

				min_scale = 100
				sld_min_scale.value = 100
				sld_min_scale.enabled = false
				lbl_min_scale.text = (min_scale as string) + "%"
				lbl_min_scale.enabled = false

				max_scale = 100
				sld_max_scale.value = 100
				sld_max_scale.enabled = false
				lbl_max_scale.text = (max_scale as string) + "%"
				lbl_max_scale.enabled = false

				ck_axis_scale.checked = false
				ck_axis_scale.enabled = false

				intr_amnt = 0
				sld_intr_amnt.value = 0
				sld_intr_amnt.enabled = false
				lbl_intr_amnt.text = (intr_amnt as string) + "%"
				lbl_intr_amnt.enabled = false
			)
			else
			(
				building_transform = false

				min_scale = 75
				sld_min_scale.value = 75
				sld_min_scale.enabled = true
				lbl_min_scale.text = (min_scale as string) + "%"
				lbl_min_scale.enabled = true

				max_scale = 200
				sld_max_scale.value = 200
				sld_max_scale.enabled = true
				lbl_max_scale.text = (max_scale as string) + "%"
				lbl_max_scale.enabled = true

				ck_axis_scale.checked = false
				ck_axis_scale.enabled = true

				intr_amnt = 0
				sld_intr_amnt.value = 0
				sld_intr_amnt.enabled = true
				lbl_intr_amnt.text = (intr_amnt as string) + "%"
				lbl_intr_amnt.enabled = true
			)
		)

		on sld_min_scale changed val do
		(
			min_scale = val
			lbl_min_scale.text = (min_scale as string) + "%"
		)

		on sld_max_scale changed val do
		(
			max_scale = val
			lbl_max_scale.text = (max_scale as string) +"%"
		)

		on ck_axis_scale changed state do
		(
			if ck_axis_scale.checked == true then
			(
				nu_scale = true
			)
			else nu_scale = false
		)

		on sld_intr_amnt changed val do
		(
			intr_amnt = val
			lbl_intr_amnt.text = (intr_amnt as string) +"%"
		)

		on pick_scatter_area picked obj do
		(
			area_obj = obj
			is_mesh = canconvertto area_obj mesh

			if is_mesh == true then
			(
				converttomesh area_obj
			)

			max = [area_obj.max.x,area_obj.max.y,area_obj.max.z]
			min = [area_obj.min.x,area_obj.min.y,area_obj.min.z]
			for i in area_obj do
			(
				if superclassof i != light and superclassof i != camera and superclassof i != SpacewarpObject then
				(
					if i.max.x >= max.x then max_x = i.max.x
					if i.max.y >= max.y then max_y = i.max.y
					if i.min.x <= min.x then min_x = i.min.x
					if i.min.y <= min.y then min_y = i.min.y
				)
			)

			lbl_what_area.text = obj.name

			do_scatter.enabled = true
		)

		on do_scatter pressed do
		(
			select_scatter.enabled = true
			delete_scatter.enabled = true

			try
			(
				if getCommandPanelTaskMode() == #modify or getCommandPanelTaskMode() == #utility then
				(
					max create mode
				)
				performScatter()
			)
			catch
			(
				select_scatter.enabled = false
				delete_scatter.enabled = false
				messagebox "Please make sure you have some objects to scatter selected." title:"LSGardener"
			)
			redrawViews()
		)

		on select_scatter pressed do
		(
			if getCommandPanelTaskMode() == #modify or getCommandPanelTaskMode() == #utility then
			(
				max create mode
			)

			try
			(
					select scattered_objects
			)
			catch
			(
				messagebox "This operation has failed. One of the scatter objects may have been deleted, or you may have restarted the script since your last scatter." title:"LSScatter"
			)

			redrawViews()
		)

		on delete_scatter pressed do
		(
			if getCommandPanelTaskMode() == #modify or getCommandPanelTaskMode() == #utility then
			(
				max create mode
			)

			undo "Delete Scatter" on
			(
				try
				(
	  				for i in scattered_objects do
					(
						delete i
					)

					for i = 1 to scattered_objects.count do
					(
						deleteItem scattered_objects 1
					)
					select holding_array
				)
				catch
				(
					messagebox "This operation has failed. One of the scatter objects may have been deleted, or you may have restarted the script since your last scatter." title:"LSScatter"
				)
			)

			select_scatter.enabled = false
			delete_scatter.enabled = false
			redrawViews()
		)

	)


	rollout plant_rollout "Plant"
	(
		label lbl_ground "Ground Object: " align:#left across:2
		label lbl_what_ground "None" align:#right

		pickbutton pickground "Pick The Ground Object" width:150 toolTip:"Pick The Ground Object" filter:geometryFilter align:#center

		button do_plant "Plant" width:150 height:40 toolTip:"Plant Selected Objects" enabled:false align:#center

		on pickground picked obj do
		(
			ground_obj = obj

			is_mesh = canConvertTo ground_obj mesh

			if is_mesh == true then
			(
				convertToMesh ground_obj
			)

			lbl_what_ground.text = obj.name
			do_plant.enabled = true

		)

		on do_plant pressed do
		(
			if ground_obj == undefined then
			(
				messagebox "Please pick a ground object" title:"LSGardener"
			)
			else
			(
				if selection.count == 0 then
				(
					messagebox "Please select some object to be planted" title:"LSGardener"
				)
				else
				(
					if getCommandPanelTaskMode() == #modify then
					(
						max create mode
					)

					performPlant()
					
					redrawViews()
				)
			)
		)
	)

	rollout locator_rollout "Location Export" rolledup:False
	(
		button do_export "Write XML File" width:150 align:#center toolTip:"Write a formatted XML file of the object locations" enabled:true
		
		on do_export pressed do
		(
			InstanceLocator()
		)
	)
	
	rollout progress_rollout "Progress" rolledup:False
	(
		progressBar progress_bar color:blue
	)

	rollout about_rollout "About" rolledUp:True
	(
		group ""
		(
			Bitmap LSG_Logo Filename:"$usericons\\LSG_Logo.bmp"
			label lbl_version ""
			label lbl_date ""
			label lbl_time ""
		)
		on about_rollout open do
		(
			lbl_version.text = LSG_version
			lbl_date.text = LSG_date
			lbl_time.text = LSG_time
		)
	)



	if LSG_floater != undefined then CloseRolloutFloater LSG_floater
	LSG_floater = newRolloutFloater "LSGardener" 200 690 1124 190
	addRollout scatter_rollout LSG_floater
	addRollout plant_rollout LSG_floater
	addRollout locator_rollout LSG_floater
	addRollout progress_rollout LSG_floater
	addRollout about_rollout LSG_floater
)