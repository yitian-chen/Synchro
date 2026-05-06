package io.github.yitianchen.synchro.scheduler;

import io.github.yitianchen.synchro.service.MatchingService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class MatchingScheduler {

    private final MatchingService matchingService;

    @Scheduled(cron = "0 0 18 * * 5") // Every Friday at 18:00 UTC
    public void runWeeklyMatching() {
        log.info("[MatchingScheduler] Starting scheduled weekly matching");
        try {
            matchingService.executeWeeklyMatching();
            log.info("[MatchingScheduler] Weekly matching completed successfully");
        } catch (Exception e) {
            log.error("[MatchingScheduler] Weekly matching failed: {}", e.getMessage(), e);
        }
    }
}
