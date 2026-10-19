package com.wayaspot.forexbot.service;

import com.wayaspot.forexbot.entity.AppSetting;
import com.wayaspot.forexbot.repo.AppSettingRepository;
import org.springframework.stereotype.Service;

import java.util.Optional;

@Service
public class SettingsService {
    private final AppSettingRepository repo;

    public SettingsService(AppSettingRepository repo) {
        this.repo = repo;
    }

    public Optional<String> get(String key) {
        return repo.findById(key).map(AppSetting::getValue);
    }

    public void set(String key, String value) {
        repo.save(new AppSetting(key, value));
    }

    public void delete(String key) {
        repo.deleteById(key);
    }
}
