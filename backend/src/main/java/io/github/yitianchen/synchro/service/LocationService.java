package io.github.yitianchen.synchro.service;

import io.github.yitianchen.synchro.model.City;
import io.github.yitianchen.synchro.model.Province;
import io.github.yitianchen.synchro.repository.CityRepository;
import io.github.yitianchen.synchro.repository.ProvinceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class LocationService {

    private final ProvinceRepository provinceRepository;
    private final CityRepository cityRepository;

    public List<Province> getAllProvinces() {
        return provinceRepository.findAll();
    }

    public List<City> getCitiesByProvince(Long provinceId) {
        return cityRepository.findByProvinceIdOrderById(provinceId);
    }
}
