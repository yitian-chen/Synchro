package io.github.yitianchen.synchro.dto.request;

import io.github.yitianchen.synchro.model.Profile;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class UpdateProfileRequest {

    @Size(max = 500, message = "Bio must be less than 500 characters")
    private String bio;

    @Min(value = 18, message = "Age must be at least 18")
    @Max(value = 100, message = "Age must be less than 100")
    private Integer age;

    private Profile.Gender gender;

    @Size(max = 255, message = "Location must be less than 255 characters")
    private String location;

    private String preferences;
}
