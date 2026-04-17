-- ─────────────────────────────────────────────────────────────────────────────
-- Seed: Competitive Event Resources
-- Populates public.competitive_event_resources with study guides, sample
-- tests, rubrics, and reference links for each FBLA competitive event.
--
-- Idempotent. Clears rows sourced as 'fbla_official' before re-seeding so
-- this file can be re-run safely during development.
-- ─────────────────────────────────────────────────────────────────────────────

-- Wipe the official seed rows so reruns produce a clean state.
delete from public.competitive_event_resources where source = 'fbla_official';

-- ── Business Management ────────────────────────────────────────────────────
insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Business Calculations',
       'Official FBLA rubric, topic outline, and format for the Business Calculations event.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'business-calculations'
union all
select id, 'Key Formulas Study Guide',
       'Profit/loss, simple & compound interest, markup/markdown, payroll, and statistics cheat sheet.',
       'study_guide', 'https://www.investopedia.com/terms/b/business-math.asp', 'fbla_official'
from public.competitive_events where slug = 'business-calculations'
union all
select id, 'Sample Practice Problems',
       'Khan Academy business math practice questions and walkthroughs.',
       'sample_test', 'https://www.khanacademy.org/math/arithmetic-home', 'fbla_official'
from public.competitive_events where slug = 'business-calculations';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Business Communication',
       'Official FBLA rubric and topic outline for Business Communication.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'business-communication'
union all
select id, 'Business Writing Essentials',
       'Formal tone, memos, emails, and report structure—everything tested on the exam.',
       'study_guide', 'https://owl.purdue.edu/owl/subject_specific_writing/professional_technical_writing/index.html', 'fbla_official'
from public.competitive_events where slug = 'business-communication';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Business Law',
       'Topic outline and test format for Business Law.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'business-law'
union all
select id, 'Contracts, Torts, and Business Ethics Overview',
       'Cornell LII primer covering the major legal concepts tested on the exam.',
       'study_guide', 'https://www.law.cornell.edu/wex/business_law', 'fbla_official'
from public.competitive_events where slug = 'business-law';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Intro to Business Concepts',
       'Topic outline and format for Introduction to Business Concepts.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'intro-business-concepts'
union all
select id, 'Intro to Business — Open Textbook',
       'OpenStax free textbook covering foundational business concepts.',
       'study_guide', 'https://openstax.org/details/books/introduction-business', 'fbla_official'
from public.competitive_events where slug = 'intro-business-concepts';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Organizational Leadership',
       'Topic outline and rubric for Organizational Leadership.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'organizational-leadership'
union all
select id, 'Leadership Theories Quick Reference',
       'Summary of transformational, servant, situational, and transactional leadership models.',
       'study_guide', 'https://www.mindtools.com/a12qdqk/leadership-styles', 'fbla_official'
from public.competitive_events where slug = 'organizational-leadership';

-- ── Finance ───────────────────────────────────────────────────────────────
insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Accounting I',
       'Topic outline and exam format for Accounting I.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'accounting-1'
union all
select id, 'Debits, Credits & The Accounting Equation',
       'AccountingCoach primer covering journal entries, ledgers, and trial balances.',
       'study_guide', 'https://www.accountingcoach.com/debits-and-credits/explanation', 'fbla_official'
from public.competitive_events where slug = 'accounting-1'
union all
select id, 'Accounting I Sample Problems',
       'Practice journal entries and t-accounts with answer keys.',
       'sample_test', 'https://www.accountingcoach.com/quizzes', 'fbla_official'
from public.competitive_events where slug = 'accounting-1';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Accounting II',
       'Topic outline and exam format for Accounting II.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'accounting-2'
union all
select id, 'Managerial Accounting Concepts',
       'Cost-volume-profit, budgeting, and variance analysis reference.',
       'study_guide', 'https://openstax.org/details/books/principles-managerial-accounting', 'fbla_official'
from public.competitive_events where slug = 'accounting-2';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Banking & Financial Systems',
       'Case study format, rubric, and presentation requirements.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'banking-financial-systems'
union all
select id, 'Federal Reserve & U.S. Banking System',
       'Fed Education primer on monetary policy and the banking system.',
       'study_guide', 'https://www.federalreserveeducation.org/', 'fbla_official'
from public.competitive_events where slug = 'banking-financial-systems';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Insurance & Risk Management',
       'Topic outline for Insurance & Risk Management.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'insurance-risk-management'
union all
select id, 'Risk Management Fundamentals',
       'Insurance Information Institute primer on risk transfer, pooling, and major insurance products.',
       'study_guide', 'https://www.iii.org/publications/insurance-handbook', 'fbla_official'
from public.competitive_events where slug = 'insurance-risk-management';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Personal Finance',
       'Topic outline for Personal Finance.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'personal-finance'
union all
select id, 'CFPB Personal Finance Curriculum',
       'Free government-produced curriculum on budgeting, credit, saving, and borrowing.',
       'study_guide', 'https://www.consumerfinance.gov/consumer-tools/educator-tools/youth-financial-education/', 'fbla_official'
from public.competitive_events where slug = 'personal-finance';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Securities & Investments',
       'Topic outline for Securities & Investments.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'securities-investments'
union all
select id, 'SEC Investor.gov — Basics',
       'Official SEC introduction to stocks, bonds, mutual funds, and ETFs.',
       'study_guide', 'https://www.investor.gov/introduction-investing/investing-basics', 'fbla_official'
from public.competitive_events where slug = 'securities-investments';

-- ── Marketing ────────────────────────────────────────────────────────────
insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Advertising',
       'Topic outline for Advertising.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'advertising'
union all
select id, 'AAF Advertising Basics',
       'American Advertising Federation intro to media planning, copy, and creative.',
       'study_guide', 'https://www.aaf.org/', 'fbla_official'
from public.competitive_events where slug = 'advertising';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Hospitality & Event Management',
       'Case study format and rubric for the team presentation.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'hospitality-event-management';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Intro to Event Planning',
       'Topic outline for Introduction to Event Planning.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'intro-event-planning'
union all
select id, 'Event Planning Checklist & Timelines',
       'Professional event planning checklist covering budget, vendors, and logistics.',
       'study_guide', 'https://www.eventbrite.com/blog/academy/event-planning-checklist/', 'fbla_official'
from public.competitive_events where slug = 'intro-event-planning';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Intro to Marketing Concepts',
       'Topic outline for Introduction to Marketing Concepts.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'intro-marketing-concepts'
union all
select id, 'Marketing — OpenStax Free Textbook',
       'Free comprehensive textbook covering the 4 Ps, consumer behavior, and segmentation.',
       'study_guide', 'https://openstax.org/details/books/principles-marketing', 'fbla_official'
from public.competitive_events where slug = 'intro-marketing-concepts';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Marketing',
       'Topic outline and exam format for Marketing.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'marketing'
union all
select id, 'American Marketing Association Resources',
       'Articles, case studies, and frameworks from the AMA.',
       'study_guide', 'https://www.ama.org/topics/', 'fbla_official'
from public.competitive_events where slug = 'marketing';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Sales Presentation',
       'Presentation rubric and format.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'sales-presentation'
union all
select id, 'Consultative Selling Framework',
       'SPIN selling and consultative sales techniques used by top reps.',
       'study_guide', 'https://blog.hubspot.com/sales/consultative-selling', 'fbla_official'
from public.competitive_events where slug = 'sales-presentation';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Social Media Strategies',
       'Project format, rubric, and deliverables.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'social-media-strategies'
union all
select id, 'Hootsuite Social Media Strategy Playbook',
       'Free template and guide for building a campaign strategy from scratch.',
       'study_guide', 'https://blog.hootsuite.com/how-to-create-a-social-media-marketing-plan/', 'fbla_official'
from public.competitive_events where slug = 'social-media-strategies';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Sports & Entertainment Management',
       'Topic outline for Sports & Entertainment Management.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'sports-entertainment-management';

-- ── Information Technology ──────────────────────────────────────────────
insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Coding & Programming',
       'Topic outline and language scope for Coding & Programming.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'coding-programming'
union all
select id, 'CS50 — Harvard''s Intro to Computer Science',
       'Free comprehensive programming course covering C, Python, and fundamental CS topics.',
       'study_guide', 'https://cs50.harvard.edu/x/', 'fbla_official'
from public.competitive_events where slug = 'coding-programming'
union all
select id, 'LeetCode Easy Problem Set',
       'Practice basic algorithm questions similar to the exam''s coding section.',
       'sample_test', 'https://leetcode.com/problemset/?difficulty=EASY', 'fbla_official'
from public.competitive_events where slug = 'coding-programming';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Computer Problem Solving',
       'Topic outline for Computer Problem Solving.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'computer-problem-solving'
union all
select id, 'CompTIA A+ Study Guide',
       'Troubleshooting hardware, software, and networking problems at the A+ level.',
       'study_guide', 'https://www.comptia.org/certifications/a', 'fbla_official'
from public.competitive_events where slug = 'computer-problem-solving';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Cybersecurity',
       'Topic outline for Cybersecurity.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'cybersecurity'
union all
select id, 'CISA Cybersecurity Fundamentals',
       'Government-authored primer covering CIA triad, threats, and defenses.',
       'study_guide', 'https://www.cisa.gov/topics/cybersecurity-best-practices', 'fbla_official'
from public.competitive_events where slug = 'cybersecurity'
union all
select id, 'TryHackMe — Pre-Security Path',
       'Free hands-on labs covering networking, Linux, and web basics.',
       'sample_test', 'https://tryhackme.com/path/outline/presecurity', 'fbla_official'
from public.competitive_events where slug = 'cybersecurity';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Database Design & Applications',
       'Topic outline for Database Design & Applications.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'database-design-applications'
union all
select id, 'SQLBolt — Interactive SQL Lessons',
       'Free interactive lessons covering SELECT, JOIN, normalization, and schema design.',
       'study_guide', 'https://sqlbolt.com/', 'fbla_official'
from public.competitive_events where slug = 'database-design-applications';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Intro to Information Technology',
       'Topic outline for Introduction to Information Technology.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'intro-information-technology'
union all
select id, 'Khan Academy — Computers and the Internet',
       'Hardware, software, networks, and internet protocols explained visually.',
       'study_guide', 'https://www.khanacademy.org/computing/computers-and-internet', 'fbla_official'
from public.competitive_events where slug = 'intro-information-technology';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Mobile Application Development',
       'Project requirements and rubric.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'mobile-application-development'
union all
select id, 'Flutter Codelabs',
       'Google''s official Flutter tutorials — a fast path to a working prototype.',
       'study_guide', 'https://docs.flutter.dev/codelabs', 'fbla_official'
from public.competitive_events where slug = 'mobile-application-development';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Network Design',
       'Topic outline for Network Design.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'network-design'
union all
select id, 'Cisco Networking Basics',
       'Free intro course covering the OSI model, subnetting, and protocols.',
       'study_guide', 'https://www.netacad.com/courses/networking-basics', 'fbla_official'
from public.competitive_events where slug = 'network-design';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Spreadsheet Applications',
       'Topic outline for Spreadsheet Applications.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'spreadsheet-applications'
union all
select id, 'Microsoft Excel Training Center',
       'Official Microsoft tutorials covering formulas, pivot tables, and charts.',
       'study_guide', 'https://support.microsoft.com/en-us/excel', 'fbla_official'
from public.competitive_events where slug = 'spreadsheet-applications';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: UX Design',
       'Project requirements and rubric for UX Design.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'ux-design'
union all
select id, 'NN/g UX Fundamentals',
       'Nielsen Norman Group — the industry standard on usability heuristics and research.',
       'study_guide', 'https://www.nngroup.com/articles/', 'fbla_official'
from public.competitive_events where slug = 'ux-design';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Website Design',
       'Project requirements and rubric for Website Design.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'website-design'
union all
select id, 'MDN Web Docs — Learn Web Development',
       'Mozilla''s free, comprehensive curriculum for HTML, CSS, and JavaScript.',
       'study_guide', 'https://developer.mozilla.org/en-US/docs/Learn', 'fbla_official'
from public.competitive_events where slug = 'website-design';

-- ── Communication ────────────────────────────────────────────────────────
insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Public Speaking',
       'Speech requirements and judging rubric.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'public-speaking'
union all
select id, 'Toastmasters — Public Speaking Tips',
       'Proven techniques for structure, delivery, and overcoming stage fright.',
       'study_guide', 'https://www.toastmasters.org/resources/public-speaking-tips', 'fbla_official'
from public.competitive_events where slug = 'public-speaking';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Impromptu Speaking',
       'Format and judging rubric for Impromptu Speaking.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'impromptu-speaking'
union all
select id, 'PREP Method for Impromptu Speeches',
       'Point–Reason–Example–Point framework — the gold standard for structured impromptus.',
       'study_guide', 'https://www.toastmasters.org/magazine/magazine-issues/2018/aug-2018/impromptu-speaking', 'fbla_official'
from public.competitive_events where slug = 'impromptu-speaking';

-- ── Economics ────────────────────────────────────────────────────────────
insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Economics',
       'Topic outline for Economics.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'economics'
union all
select id, 'Khan Academy Microeconomics + Macroeconomics',
       'Full video course covering both exam halves.',
       'study_guide', 'https://www.khanacademy.org/economics-finance-domain', 'fbla_official'
from public.competitive_events where slug = 'economics';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Macroeconomics',
       'Topic outline for Macroeconomics.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'macroeconomics'
union all
select id, 'Federal Reserve FRED — Macro Data',
       'Live data on GDP, inflation, unemployment — useful for context and currency.',
       'study_guide', 'https://fred.stlouisfed.org/', 'fbla_official'
from public.competitive_events where slug = 'macroeconomics';

-- ── Entrepreneurship ──────────────────────────────────────────────────────
insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Entrepreneurship',
       'Business plan format, presentation rubric, and team requirements.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'entrepreneurship'
union all
select id, 'Business Model Canvas (Strategyzer)',
       'The industry-standard one-page planning template — great for the written component.',
       'study_guide', 'https://www.strategyzer.com/library/the-business-model-canvas', 'fbla_official'
from public.competitive_events where slug = 'entrepreneurship'
union all
select id, 'SBA — Write Your Business Plan',
       'Small Business Administration''s official step-by-step business plan guide.',
       'study_guide', 'https://www.sba.gov/business-guide/plan-your-business/write-your-business-plan', 'fbla_official'
from public.competitive_events where slug = 'entrepreneurship';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Future Business Leader',
       'Exam + interview format and rubric.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'future-business-leader';

-- ── Leadership ──────────────────────────────────────────────────────────
insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Parliamentary Procedure',
       'Team format, problem set, and rubric.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'parliamentary-procedure'
union all
select id, 'Robert''s Rules of Order — Quick Reference',
       'Motions chart, precedence, and common scenarios used in the problem round.',
       'study_guide', 'https://robertsrules.com/', 'fbla_official'
from public.competitive_events where slug = 'parliamentary-procedure';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Political Science',
       'Topic outline for Political Science.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'political-science'
union all
select id, 'Crash Course U.S. Government and Politics',
       '50-episode video series covering the Constitution, branches, and elections.',
       'video', 'https://thecrashcourse.com/courses/uspolitics', 'fbla_official'
from public.competitive_events where slug = 'political-science';

-- ── Career Development ──────────────────────────────────────────────────
insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Job Interview',
       'Resume, cover letter, and live interview rubric.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'job-interview'
union all
select id, 'STAR Method for Interview Answers',
       'Situation–Task–Action–Result framework — the standard for behavioral answers.',
       'study_guide', 'https://www.themuse.com/advice/star-interview-method', 'fbla_official'
from public.competitive_events where slug = 'job-interview'
union all
select id, 'Harvard Resume & Cover Letter Guide',
       'The gold standard one-page resume & cover letter templates.',
       'pdf', 'https://ocs.fas.harvard.edu/guide-resumes-cover-letters', 'fbla_official'
from public.competitive_events where slug = 'job-interview';

insert into public.competitive_event_resources (event_id, title, description, resource_type, url, source)
select id, 'Official FBLA Competitive Event Guide: Intro to Business Procedures',
       'Topic outline for Introduction to Business Procedures.',
       'link', 'https://www.fbla.org/high-school/competitive-events/', 'fbla_official'
from public.competitive_events where slug = 'intro-business-procedures'
union all
select id, 'Office Procedures & Ethics Reference',
       'Overview of professional office procedures, records management, and workplace ethics.',
       'study_guide', 'https://www.investopedia.com/terms/b/business-ethics.asp', 'fbla_official'
from public.competitive_events where slug = 'intro-business-procedures';
