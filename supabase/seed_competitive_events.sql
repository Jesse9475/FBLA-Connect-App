-- ─────────────────────────────────────────────────────────────────────────────
-- Seed: FBLA Competitive Events
-- Run this in Supabase SQL editor to populate the competitive_events table.
-- Idempotent — uses ON CONFLICT (slug) to upsert.
-- ─────────────────────────────────────────────────────────────────────────────

insert into public.competitive_events (name, slug, category, description, event_type, is_individual, team_size_min, team_size_max) values
-- Business Management
('Business Calculations', 'business-calculations', 'business_management', 'Apply mathematical concepts to solve business-related problems including profit/loss, interest, and statistics.', 'test', true, 1, 1),
('Business Communication', 'business-communication', 'business_management', 'Demonstrate written, verbal, and electronic communication skills critical to business success.', 'test', true, 1, 1),
('Business Law', 'business-law', 'business_management', 'Test your knowledge of legal principles affecting business operations and ethics.', 'test', true, 1, 1),
('Introduction to Business Concepts', 'intro-business-concepts', 'business_management', 'Foundational concepts of business operations, organization, and strategy.', 'test', true, 1, 1),
('Organizational Leadership', 'organizational-leadership', 'leadership', 'Leadership theory, team management, and organizational behavior.', 'test', true, 1, 1),

-- Finance
('Accounting I', 'accounting-1', 'finance', 'Foundational accounting principles, financial statements, and bookkeeping practices.', 'test', true, 1, 1),
('Accounting II', 'accounting-2', 'finance', 'Advanced accounting topics including managerial accounting and financial analysis.', 'test', true, 1, 1),
('Banking & Financial Systems', 'banking-financial-systems', 'finance', 'Team event analyzing a banking case study and presenting solutions.', 'presentation', false, 2, 3),
('Insurance & Risk Management', 'insurance-risk-management', 'finance', 'Concepts of risk, insurance products, and risk mitigation strategies.', 'test', true, 1, 1),
('Personal Finance', 'personal-finance', 'finance', 'Budgeting, saving, investing, credit, and personal financial planning.', 'test', true, 1, 1),
('Securities & Investments', 'securities-investments', 'finance', 'Investment vehicles, portfolio management, and capital markets.', 'test', true, 1, 1),

-- Marketing
('Advertising', 'advertising', 'marketing', 'Concepts of advertising including media planning, copywriting, and campaign analysis.', 'test', true, 1, 1),
('Hospitality & Event Management', 'hospitality-event-management', 'marketing', 'Plan and manage events in the hospitality industry. Team presentation event.', 'presentation', false, 2, 3),
('Introduction to Event Planning', 'intro-event-planning', 'marketing', 'Foundational principles of planning successful events.', 'test', true, 1, 1),
('Introduction to Marketing Concepts', 'intro-marketing-concepts', 'marketing', 'Foundations of marketing including the four Ps and consumer behavior.', 'test', true, 1, 1),
('Marketing', 'marketing', 'marketing', 'Comprehensive marketing test covering strategy, branding, and analytics.', 'test', true, 1, 1),
('Sales Presentation', 'sales-presentation', 'marketing', 'Deliver a sales pitch for a product or service to a panel of judges.', 'presentation', true, 1, 1),
('Social Media Strategies', 'social-media-strategies', 'marketing', 'Team event developing a social media strategy for a real organization.', 'presentation', false, 1, 3),
('Sports & Entertainment Management', 'sports-entertainment-management', 'marketing', 'Marketing and management concepts in sports and entertainment industries.', 'test', true, 1, 1),

-- Information Technology
('Coding & Programming', 'coding-programming', 'information_technology', 'Solve programming problems and demonstrate code logic.', 'test', true, 1, 1),
('Computer Problem Solving', 'computer-problem-solving', 'information_technology', 'Diagnose and resolve common computing issues.', 'test', true, 1, 1),
('Cybersecurity', 'cybersecurity', 'information_technology', 'Test of cybersecurity concepts including threats, defenses, and best practices.', 'test', true, 1, 1),
('Database Design & Applications', 'database-design-applications', 'information_technology', 'Database concepts including normalization, SQL, and relational design.', 'test', true, 1, 1),
('Introduction to Information Technology', 'intro-information-technology', 'information_technology', 'Foundational IT concepts including hardware, software, and networks.', 'test', true, 1, 1),
('Mobile Application Development', 'mobile-application-development', 'information_technology', 'Team event to design and present a mobile app prototype.', 'project', false, 1, 3),
('Network Design', 'network-design', 'information_technology', 'Concepts of network architecture, protocols, and topology.', 'test', true, 1, 1),
('Spreadsheet Applications', 'spreadsheet-applications', 'information_technology', 'Demonstrate proficiency in spreadsheet formulas, functions, and analysis.', 'test', true, 1, 1),
('UX Design', 'ux-design', 'information_technology', 'Team event to design and present a user experience for a product.', 'project', false, 1, 3),
('Website Design', 'website-design', 'information_technology', 'Team event to build and present a functional website.', 'project', false, 1, 3),

-- Communication
('Public Speaking', 'public-speaking', 'communication', 'Deliver an original speech on a business topic.', 'presentation', true, 1, 1),
('Impromptu Speaking', 'impromptu-speaking', 'communication', 'Deliver an unprepared speech on a randomly assigned topic.', 'performance', true, 1, 1),

-- Economics
('Economics', 'economics', 'economics', 'Test of micro and macroeconomic concepts and policy.', 'test', true, 1, 1),
('Macroeconomics', 'macroeconomics', 'economics', 'Advanced concepts of national and global economic systems.', 'test', true, 1, 1),

-- Entrepreneurship
('Entrepreneurship', 'entrepreneurship', 'entrepreneurship', 'Team event presenting a business plan for a new venture.', 'presentation', false, 2, 3),
('Future Business Leader', 'future-business-leader', 'entrepreneurship', 'Comprehensive test plus interview event covering business knowledge and leadership.', 'test', true, 1, 1),

-- Leadership
('Parliamentary Procedure', 'parliamentary-procedure', 'leadership', 'Team event demonstrating mastery of Robert''s Rules of Order.', 'performance', false, 4, 5),
('Political Science', 'political-science', 'leadership', 'Test covering political institutions, ideologies, and processes.', 'test', true, 1, 1),

-- Career Development
('Job Interview', 'job-interview', 'career_development', 'Demonstrate interviewing skills with a resume, cover letter, and live interview.', 'presentation', true, 1, 1),
('Introduction to Business Procedures', 'intro-business-procedures', 'career_development', 'Foundational office and business procedures.', 'test', true, 1, 1)
on conflict (slug) do update set
  name = excluded.name,
  category = excluded.category,
  description = excluded.description,
  event_type = excluded.event_type,
  is_individual = excluded.is_individual,
  team_size_min = excluded.team_size_min,
  team_size_max = excluded.team_size_max;
