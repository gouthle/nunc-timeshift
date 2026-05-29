# Nunc

Nunc is a simple and elegant iOS app for tracking work shifts, calculating salary, and planning how your monthly income will be distributed.

The app helps you answer two questions:

- How much have I earned from my shifts?
- Where will my salary go?

## Features

### Work Tracking

- Start and end shifts manually
- Add shifts directly from the calendar
- Create reusable shift presets
- Track worked hours and planned hours
- Calculate salary based on hourly rate
- View monthly work statistics
- See shift duration, earnings, and progress after each worked shift

### Calendar

- Monthly shift overview
- Color indicators for short, normal, and long shifts
- Quick shift assignment using presets
- Edit or delete shifts
- View daily shift details

### Statistics

- Monthly earned amount
- Worked hours vs planned hours
- Days until payday
- Longest shift
- Shift duration breakdown
- Weekly worked hours chart

### Money Planning

Nunc includes a premium-style Money section for salary allocation.

- View planned monthly salary
- See earned amount so far
- Allocate money into expense categories
- Track assigned and unassigned money
- Mark expenses as already paid
- Visualize salary distribution with a chart

## Premium Concept

The Money section is designed as a premium feature. It includes a lock/unlock interaction inspired by Face ID, giving the app a polished and premium feel.

## Tech Stack

- Swift
- SwiftUI
- Combine
- UserDefaults for local persistence
- iOS native components and animations

## Project Structure

```text
Nunc/
├── AnimationExtensions.swift
├── AppLanguage.swift
├── BudgetStore.swift
├── BudgetView.swift
├── CalendarView.swift
├── ContentView.swift
├── NuncApp.swift
├── SettingsView.swift
├── ShiftStore.swift
├── ShiftView.swift
└── StatsView.swift

Setup
Open the project in Xcode.
Make sure all Swift files are included in the Nunc target.
Build and run the app on an iPhone simulator or physical device.
Set your hourly rate in Settings.
Add shifts through the calendar or start a shift manually.
Notes
Nunc currently stores data locally using UserDefaults. It does not require an account or internet connection.

Roadmap Ideas
Real premium purchase integration
Monthly budget templates
Export salary and budget reports
iCloud sync
More advanced salary rules
Overtime and bonus support
License
This project is currently private.
