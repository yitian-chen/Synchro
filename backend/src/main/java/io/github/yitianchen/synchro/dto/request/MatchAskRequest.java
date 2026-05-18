package io.github.yitianchen.synchro.dto.request;

import jakarta.validation.constraints.NotBlank;

public record MatchAskRequest(@NotBlank String question) {}
