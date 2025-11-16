shader_type canvas_item;

// Swirl transition parameters
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float swirl_strength : hint_range(0.0, 10.0) = 5.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform float radius : hint_range(0.0, 2.0) = 1.0;

void fragment() {
    vec2 uv = UV;
    vec2 dir = uv - center;
    float dist = length(dir);
    
    // Calculate swirl amount based on distance and progress
    float swirl_amount = swirl_strength * progress * (1.0 - smoothstep(0.0, radius, dist));
    
    // Rotate UV coordinates
    float angle = swirl_amount;
    float s = sin(angle);
    float c = cos(angle);
    
    vec2 rotated = vec2(
        dir.x * c - dir.y * s,
        dir.x * s + dir.y * c
    );
    
    vec2 new_uv = center + rotated;
    
    // Sample texture with swirled coordinates
    vec4 color = texture(TEXTURE, new_uv);
    
    // Fade to black as transition progresses
    float fade = smoothstep(0.7, 1.0, progress);
    color.rgb = mix(color.rgb, vec3(0.0), fade);
    
    COLOR = color;
}
