//
// Simple passthrough vertex shader
//
attribute vec3 in_Position;
varying vec2 v_world;

void main() {
	v_world = in_Position.xy;
	gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * vec4(in_Position, 1.0);
}