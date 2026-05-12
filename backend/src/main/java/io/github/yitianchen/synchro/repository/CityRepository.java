package io.github.yitianchen.synchro.repository;

import io.github.yitianchen.synchro.model.City;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface CityRepository extends JpaRepository<City, Long> {
    List<City> findByProvinceIdOrderById(Long provinceId);
}
