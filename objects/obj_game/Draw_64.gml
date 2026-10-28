// Draw GUI event of obj_game (screen space)

if (gameState == GAME_STATE.MENU) {
	draw_menu(id);
} else {
	draw_hud(id);
}
draw_fps_counter(id);
//draw_set_colour(c_white);
//draw_text(10, 100, audio_debug_text());