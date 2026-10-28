// Draw GUI event of obj_game (screen space)

if (gameState == GAME_STATE.MENU) {
	draw_menu(id);
} else {
	draw_hud(id);
	rename_draw(id);
}
draw_fps_counter(id);

//draw_set_colour(c_white);
//draw_text(10, 100, audio_debug_text());

if (net_is_online() && global.net.stalled && (gameState == GAME_STATE.PLAYING)) {
	draw_set_halign(fa_center);
	draw_set_colour(c_white);
	draw_text(screenW / 2, TOP_H + 12, "Waiting for other players...");
	draw_set_halign(fa_left);
}