package io.github.yitianchen.synchro.controller;

import io.github.yitianchen.synchro.model.City;
import io.github.yitianchen.synchro.model.Province;
import io.github.yitianchen.synchro.service.LocationService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/locations")
@RequiredArgsConstructor
public class LocationController {

    private final LocationService locationService;

    @GetMapping("/provinces")
    public ResponseEntity<List<Province>> getProvinces() {
        return ResponseEntity.ok(locationService.getAllProvinces());
    }

    @GetMapping("/cities")
    public ResponseEntity<List<City>> getCities(@RequestParam Long provinceId) {
        return ResponseEntity.ok(locationService.getCitiesByProvince(provinceId));
    }
}
