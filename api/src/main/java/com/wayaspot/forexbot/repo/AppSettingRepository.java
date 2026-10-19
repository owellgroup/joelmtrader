package com.wayaspot.forexbot.repo;

import com.wayaspot.forexbot.entity.AppSetting;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AppSettingRepository extends JpaRepository<AppSetting, String> {
}
