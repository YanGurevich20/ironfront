shader_type canvas_item;

// Control parameters
uniform float destruction_progress : hint_range(0.0, 1.0) = 1;
uniform float burn_intensity : hint_range(0.0, 2.0) = 6.0;
uniform float rust_intensity : hint_range(0.0, 2.0) = 0.1;
uniform float noise_scale : hint_range(0.1, 10.0) = 10;

// Color parameters
uniform vec4 rust_color : source_color = vec4(0.6, 0.3, 0.1, 1.0);
uniform vec4 burn_color : source_color = vec4(0.1, 0.05, 0.0, 1.0);
uniform vec4 char_color : source_color = vec4(0.05, 0.05, 0.05, 1.0);

// Simple noise function
float noise(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

// Multi-octave noise for more natural patterns
float fbm(vec2 uv) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(uv * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }

    return value;
}

void fragment() {
    vec2 uv = UV;
    vec4 original_color = texture(TEXTURE, uv);

    // Process all pixels, but only apply effects to non-transparent ones
    if (original_color.a > 0.01) {
        // Generate noise patterns for rust and burn effects
        vec2 noise_uv = vec2(0.5, 0.5) * noise_scale;
        float rust_noise = fbm(noise_uv);
        float burn_noise = fbm(noise_uv + vec2(100.0, 50.0));
        float char_noise = fbm(noise_uv + vec2(200.0, 150.0));

        // Create masks based on noise and destruction progress
        float rust_mask = smoothstep(0.3, 0.8, rust_noise) * destruction_progress;
        float burn_mask = smoothstep(0.4, 0.9, burn_noise) * destruction_progress;
        float char_mask = smoothstep(0.6, 1.0, char_noise) * destruction_progress;

        // Darken the original color as it gets destroyed
        vec3 darkened_original = original_color.rgb * (1.0 - destruction_progress * 0.5);

        // Apply rust effect
        vec3 rusted_color = mix(darkened_original, rust_color.rgb, rust_mask * rust_intensity);

        // Apply burn/char effect
        vec3 burned_color = mix(rusted_color, burn_color.rgb, burn_mask * burn_intensity * 0.7);

        // Apply heavy charring for the most destroyed areas
        vec3 final_color = mix(burned_color, char_color.rgb, char_mask);

        // Add some edge darkening for depth
        float edge_factor = 1.0 - smoothstep(0.0, 0.3, distance(uv, vec2(0.5)));
        final_color *= 1.0 - (edge_factor * destruction_progress * 0.3);

        // Reduce saturation as destruction increases
        float gray = dot(final_color, vec3(0.299, 0.587, 0.114));
        final_color = mix(final_color, vec3(gray), destruction_progress * 0.4);

        COLOR = vec4(final_color, original_color.a);
    } else {
        COLOR = original_color;
    }
}