shader_type canvas_item;

// Allows grabbing the screen buffer behind the ColorRect
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform float blur_amount : hint_range(0.0, 5.0) = 2.0;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.4;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    // 1. BLUR EFFECT (using lod/mipmaps)
    vec4 screen_color = textureLod(screen_texture, SCREEN_UV, blur_amount);
    
    // 2. VIGNETTE EFFECT
    // Calculate distance from screen center
    vec2 uv = UV - 0.5;
    float dist = length(uv);
    
    // Smoothly interpolate the darkness towards edges
    float vignette = smoothstep(0.5, 0.5 - vignette_intensity, dist);
    
    // Mix the blurred screen color with the black vignette color
    vec3 final_color = mix(vec3(0.0), screen_color.rgb, vignette);
    
    COLOR = vec4(final_color, vignette_opacity);
}
