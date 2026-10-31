//
// Simple passthrough vertex shader
//
attribute vec3 in_Position;
attribute vec4 in_Colour;

varying vec2 v_world;
varying vec4 v_data;

void main() {
	v_world = in_Position.xy;
	v_data = in_Colour;
	gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * vec4(in_Position, 1.0);
}