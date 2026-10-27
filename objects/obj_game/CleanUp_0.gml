// Clean Up event of obj_game

save_options();
if (world != undefined) {
	destroy_world(world);
}
camera_destroy(cam);