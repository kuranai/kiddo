# Family Todo/Rewards App - Implementation Plan

## Project Overview
A simplified family todo list and rewards system where kids and parents can create todos, earn points, and redeem rewards. Built with Rails 8.0, TailwindCSS, and DaisyUI.

## Core Features
- ✅ Basic user authentication (parent/kid roles)
- ✅ Todo creation and assignment
- ✅ Point system for completed todos
- ✅ Rewards catalog and redemption
- ✅ Recurring todos
- ✅ Family-wide todos (claimable by anyone)
- ✅ Simple dashboard and mobile-friendly UI

---

## Phase 1: Authentication & User Management

### 1.1 Set up Authentication
- [x] Add `bcrypt` gem to Gemfile
- [x] Generate User model with authentication fields
- [x] Add user roles: `:parent` and `:kid`
- [x] Create authentication controller (sessions)
- [x] Create user registration/login views with DaisyUI
- [x] Add before_action filters for authentication

### 1.2 User Model Setup
- [x] User attributes: `name:string`, `email:string`, `password_digest:string`, `role:integer`, `points_balance:integer`
- [x] User model validations and enums
- [x] Add helper methods: `parent?`, `kid?`, `can_create_todos_for?(user)`

---

## Phase 2: Core Data Models

### 2.1 Todo Model
- [x] Generate Todo model
- [x] Todo attributes: `title:string`, `description:text`, `points:integer`, `assignee_id:integer`, `creator_id:integer`, `due_date:datetime`, `completed:boolean`, `completed_at:datetime`
- [x] Add associations: `belongs_to :assignee, class_name: 'User'`, `belongs_to :creator, class_name: 'User'`
- [x] Add validations and scopes
- [x] Add methods: `completable_by?(user)`, `complete!`, `overdue?`

### 2.2 Recurring Todos
- [x] Add recurring fields to Todo: `recurring:boolean`, `recurring_type:integer` (daily/weekly/monthly), `recurring_days:text`
- [x] Add `family_wide:boolean` field to Todo model
- [x] Add logic to generate new todos based on recurring templates (`generate_next_occurrence`)
- [ ] Set up Solid Queue job for creating recurring todos (moved to Phase 4)

### 2.3 Reward Model
- [x] Generate Reward model
- [x] Reward attributes: `name:string`, `description:text`, `point_cost:integer`, `active:boolean`
- [x] Add validations
- [x] Add methods: `affordable_by?(user)`, `redeem_for!(user)`

### 2.4 Point Transaction Model
- [x] Generate PointTransaction model
- [x] PointTransaction attributes: `user:references`, `amount:integer`, `description:string`, `todo:references`, `reward:references`, `transaction_type:integer`
- [x] Add associations and validations
- [x] Add scopes: `earnings`, `spendings`, `recent`
- [x] Update User model with `add_points` and `deduct_points` methods
- [x] Integrate point transactions with todo completion and reward redemption

---

## Phase 3: Controllers & Routes

### 3.1 Authentication Controllers
- [x] Create SessionsController (login/logout)
- [x] Create UsersController (registration for parents only)
- [x] Set up authentication routes
- [x] Add redirect logic after login (parent vs kid dashboards)

### 3.2 Todo Controllers
- [x] Create TodosController with CRUD actions
- [x] Add authorization: parents can create for anyone, kids only for themselves
- [x] Add complete action for marking todos done
- [x] Add claim action for family-wide todos
- [x] Add filters: my_todos, family_todos, completed, pending, overdue, created_by_me
- [x] Add unclaim action for family-wide todos

### 3.3 Reward Controllers
- [x] Create RewardsController (parents can CRUD, kids can view/redeem)
- [x] Add redeem action with point deduction
- [x] Add authorization logic
- [x] Add toggle_active action for managing reward availability
- [x] Add affordable filter for kids to see redeemable rewards

### 3.4 Dashboard Controller
- [x] Create DashboardController
- [x] Parent dashboard: family overview, create todos, manage rewards
- [x] Kid dashboard: my todos, my points, available rewards
- [x] Enhanced with role-based data: stats, recent activity, family-wide todos

---

## Phase 4: Background Jobs & Recurring Tasks

### 4.1 Recurring Todo Job
- [x] Create RecurringTodoJob using Solid Queue
- [x] Job logic: find due recurring todos, create new instances
- [x] Schedule job to run daily
- [x] Add job monitoring and error handling

### 4.2 Point Management
- [x] Create PointTransactionService
- [x] Auto-award points when todo is completed
- [x] Deduct points when reward is redeemed
- [x] Update user point balances atomically

---

## Phase 5: Views & UI with DaisyUI

### 5.1 Layout & Navigation
- [ ] Create application layout with DaisyUI components
- [ ] Add navigation bar with user info and logout
- [ ] Add responsive design for mobile/desktop
- [ ] Create flash message styling

### 5.2 Authentication Views
- [ ] Login form with DaisyUI styling
- [ ] User registration form (parents only)
- [ ] Add form validation styling

### 5.3 Dashboard Views
- [ ] Parent dashboard: stats cards, quick actions, family activity
- [ ] Kid dashboard: my todos, points balance, reward gallery
- [ ] Add point balance display in header

### 5.4 Todo Views
- [ ] Todo index with filtering (all/mine/completed)
- [ ] Todo form (new/edit) with DaisyUI components
- [ ] Todo cards with complete buttons
- [ ] Recurring todo indicators
- [ ] Family todo badges

### 5.5 Reward Views
- [ ] Rewards catalog grid layout
- [ ] Reward cards with point costs
- [ ] Redeem buttons with confirmation modals
- [ ] Reward management for parents

---

## Phase 6: Advanced Features

### 6.1 Family-wide Todos
- [ ] Add `family_wide:boolean` to Todo model
- [ ] Add claiming logic (first come, first served)
- [ ] Show claimed status and claimer name
- [ ] Add claim/unclaim actions

### 6.2 Todo Categories & Tags
- [ ] Add optional categories (chores, homework, etc.)
- [ ] Add color coding for different categories
- [ ] Add filtering by category

### 6.3 Statistics & Progress
- [ ] Add stats to dashboards: weekly points, completion rates
- [ ] Create simple charts with Chart.js or similar
- [ ] Add leaderboard for family members

### 6.4 Photo Uploads (Optional)
- [ ] Add Active Storage for photo uploads
- [ ] Allow photos as proof of completion
- [ ] Add photo gallery for completed todos

---

## Phase 7: Testing & Polish

### 7.1 Testing
- [ ] Write model tests for all core models
- [ ] Write controller tests for main actions
- [ ] Write system tests for key user flows
- [ ] Test authorization logic thoroughly

### 7.2 Seeds & Sample Data
- [ ] Create db/seeds.rb with sample family data
- [ ] Add sample todos and rewards
- [ ] Create test users (1 parent, 2 kids)

### 7.3 Polish & UX
- [ ] Add loading states for async actions
- [ ] Add confirmation dialogs for important actions
- [ ] Add keyboard shortcuts for common actions
- [ ] Add mobile-specific optimizations

---

## Deployment Preparation

### 8.1 Production Setup
- [ ] Configure production database
- [ ] Set up Solid Queue in production
- [ ] Add proper logging
- [ ] Set up basic monitoring

### 8.2 Security Review
- [ ] Run Brakeman security scan
- [ ] Review authorization logic
- [ ] Add rate limiting if needed
- [ ] Secure sensitive routes

---

## Implementation Notes

### Technology Stack
- **Backend**: Rails 8.0.2+, SQLite 3
- **Frontend**: TailwindCSS, DaisyUI, Turbo, Stimulus
- **Jobs**: Solid Queue
- **Authentication**: Custom with bcrypt (keeping it simple)
- **Deployment**: Kamal (already configured)

### Key Design Decisions
- Single family system (no invitations needed)
- Simple role-based authorization
- Direct point redemption (no approval workflow)
- SQLite for simplicity
- Mobile-first responsive design

### Development Order
1. Start with basic authentication and user management
2. Build core todo functionality
3. Add point system and rewards
4. Implement recurring todos
5. Polish UI and add advanced features
6. Add testing and deployment prep

---

## Progress Tracking
- [x] Phase 1: Authentication & User Management ✅
- [x] Phase 2: Core Data Models ✅
- [x] Phase 3: Controllers & Routes ✅
- [x] Phase 4: Background Jobs & Recurring Tasks ✅
- [ ] Phase 5: Views & UI with DaisyUI
- [ ] Phase 6: Advanced Features
- [ ] Phase 7: Testing & Polish
- [ ] Phase 8: Deployment Preparation

**Started**: September 9, 2025
**Target Completion**: [Date]
**Status**: Phase 4 Complete ✅ - Background jobs and recurring tasks with PointTransactionService implemented!

---

## Next Steps
1. Build todo and reward views with DaisyUI
2. Enhanced dashboard views with statistics
3. Point transaction history views
4. Mobile-optimized responsive UI
5. Advanced features and testing

*This document will be updated as features are implemented and requirements evolve.*