-- ─────────────────────────────────────────────────────────────────────────────
-- Seed: Competitive Event Practice Quizzes
-- Populates public.quizzes + public.quiz_questions with a starter set of
-- multiple-choice practice problems for the most-competed FBLA events.
--
-- Idempotent. Deletes all quizzes where created_by IS NULL (i.e. system
-- seeds) before re-inserting, so this file can be re-run safely. Questions
-- are removed automatically via ON DELETE CASCADE.
-- ─────────────────────────────────────────────────────────────────────────────

delete from public.quizzes where created_by is null;

-- ── Quizzes ──────────────────────────────────────────────────────────────
insert into public.quizzes (event_id, title, description, question_count, difficulty, time_limit_seconds, points_per_correct, is_ai_generated)
select id, 'Business Calculations — Warm-up',
       'Five classic questions covering profit, interest, and payroll math.',
       5, 'medium', 300, 10, false
from public.competitive_events where slug = 'business-calculations'
union all
select id, 'Accounting I — Fundamentals',
       'Basic bookkeeping, the accounting equation, and common journal entries.',
       5, 'easy', 300, 10, false
from public.competitive_events where slug = 'accounting-1'
union all
select id, 'Marketing — Core Concepts',
       'The 4 P''s, segmentation, positioning, and consumer behavior basics.',
       5, 'easy', 300, 10, false
from public.competitive_events where slug = 'marketing'
union all
select id, 'Intro to IT — Vocabulary',
       'Hardware, software, and networking terms every IT competitor should know.',
       5, 'easy', 300, 10, false
from public.competitive_events where slug = 'intro-information-technology'
union all
select id, 'Economics — Micro & Macro Basics',
       'Supply, demand, elasticity, and key macro indicators.',
       5, 'medium', 300, 10, false
from public.competitive_events where slug = 'economics'
union all
select id, 'Public Speaking — Delivery Basics',
       'Structure, pacing, and audience engagement — the judging essentials.',
       5, 'easy', 300, 10, false
from public.competitive_events where slug = 'public-speaking';

-- ── Business Calculations questions ──────────────────────────────────────
insert into public.quiz_questions (quiz_id, question_text, question_type, options, correct_answer, explanation, sort_order)
select q.id, 'A retailer buys an item for $40 and sells it for $60. What is the markup percentage?',
       'multiple_choice',
       '["33%","40%","50%","67%"]'::jsonb, '50%',
       'Markup % = (Selling - Cost) / Cost × 100 = 20/40 × 100 = 50%.', 1
from public.quizzes q where q.title = 'Business Calculations — Warm-up' union all
select q.id, 'If you deposit $1,000 at 5% simple interest for 3 years, how much interest do you earn?',
       'multiple_choice',
       '["$50","$150","$157.63","$300"]'::jsonb, '$150',
       'Simple interest = P × r × t = 1000 × 0.05 × 3 = $150.', 2
from public.quizzes q where q.title = 'Business Calculations — Warm-up' union all
select q.id, 'An employee earns $18/hour and works 42 hours (2 hours of overtime at 1.5×). Gross pay?',
       'multiple_choice',
       '["$720","$738","$774","$810"]'::jsonb, '$774',
       '40 × $18 = $720 regular; 2 × $27 = $54 OT; total $774.', 3
from public.quizzes q where q.title = 'Business Calculations — Warm-up' union all
select q.id, 'Net sales are $50,000 and cost of goods sold is $30,000. What is gross profit?',
       'multiple_choice',
       '["$15,000","$20,000","$30,000","$80,000"]'::jsonb, '$20,000',
       'Gross profit = Net sales − COGS = 50,000 − 30,000 = $20,000.', 4
from public.quizzes q where q.title = 'Business Calculations — Warm-up' union all
select q.id, 'A $200 jacket is marked down 25%. What is the sale price?',
       'multiple_choice',
       '["$125","$150","$160","$175"]'::jsonb, '$150',
       'Discount = 200 × 0.25 = $50. Sale price = 200 − 50 = $150.', 5
from public.quizzes q where q.title = 'Business Calculations — Warm-up';

-- ── Accounting I questions ───────────────────────────────────────────────
insert into public.quiz_questions (quiz_id, question_text, question_type, options, correct_answer, explanation, sort_order)
select q.id, 'Which equation is the foundation of double-entry accounting?',
       'multiple_choice',
       '["Assets = Liabilities + Equity","Revenue − Expenses = Net Income","Debits = Credits","Cash In − Cash Out = Profit"]'::jsonb,
       'Assets = Liabilities + Equity',
       'The accounting equation keeps the balance sheet in balance.', 1
from public.quizzes q where q.title = 'Accounting I — Fundamentals' union all
select q.id, 'A debit to Cash and a credit to Sales Revenue records what?',
       'multiple_choice',
       '["A purchase","A cash sale","A loan payment","A depreciation entry"]'::jsonb,
       'A cash sale',
       'Cash increases (debit asset); revenue is earned (credit revenue).', 2
from public.quizzes q where q.title = 'Accounting I — Fundamentals' union all
select q.id, 'Which is a current asset?',
       'multiple_choice',
       '["Equipment","Accounts Payable","Inventory","Long-term Debt"]'::jsonb,
       'Inventory',
       'Inventory is typically converted to cash within one year.', 3
from public.quizzes q where q.title = 'Accounting I — Fundamentals' union all
select q.id, 'Depreciation is an example of what type of expense?',
       'multiple_choice',
       '["Operating / non-cash","Interest","Cost of goods sold","Tax"]'::jsonb,
       'Operating / non-cash',
       'Depreciation allocates the cost of a fixed asset over its useful life — no cash leaves the business.', 4
from public.quizzes q where q.title = 'Accounting I — Fundamentals' union all
select q.id, 'The difference between revenue and expenses is called:',
       'multiple_choice',
       '["Equity","Gross margin","Net income","Retained earnings"]'::jsonb,
       'Net income',
       'Net income (loss) = Revenue − Expenses. It flows into retained earnings at period end.', 5
from public.quizzes q where q.title = 'Accounting I — Fundamentals';

-- ── Marketing questions ──────────────────────────────────────────────────
insert into public.quiz_questions (quiz_id, question_text, question_type, options, correct_answer, explanation, sort_order)
select q.id, 'Which of these is NOT one of the traditional 4 P''s of marketing?',
       'multiple_choice',
       '["Product","Price","People","Promotion"]'::jsonb,
       'People',
       'The 4 P''s are Product, Price, Place, Promotion. People is part of the extended 7 P''s.', 1
from public.quizzes q where q.title = 'Marketing — Core Concepts' union all
select q.id, 'Dividing a broad market into smaller groups of similar customers is called:',
       'multiple_choice',
       '["Positioning","Segmentation","Branding","Targeting"]'::jsonb,
       'Segmentation',
       'Segmentation → Targeting → Positioning is the STP framework.', 2
from public.quizzes q where q.title = 'Marketing — Core Concepts' union all
select q.id, 'A brand''s unique place in the customer''s mind compared to competitors is called:',
       'multiple_choice',
       '["Segmentation","Positioning","Promotion","Placement"]'::jsonb,
       'Positioning',
       'Positioning defines how you want customers to perceive your brand vs. alternatives.', 3
from public.quizzes q where q.title = 'Marketing — Core Concepts' union all
select q.id, 'Which is a primary purpose of market research?',
       'multiple_choice',
       '["Reduce taxes","Understand customer needs","Hire employees","Calculate depreciation"]'::jsonb,
       'Understand customer needs',
       'Market research informs product, pricing, and promotion decisions based on customer needs.', 4
from public.quizzes q where q.title = 'Marketing — Core Concepts' union all
select q.id, 'AIDA stands for:',
       'multiple_choice',
       '["Awareness, Interest, Desire, Action","Ask, Involve, Deliver, Act","Attention, Impact, Data, Acquire","Audience, Intent, Decide, Adopt"]'::jsonb,
       'Awareness, Interest, Desire, Action',
       'AIDA is a classic sales-funnel model describing how buyers progress through an ad or pitch.', 5
from public.quizzes q where q.title = 'Marketing — Core Concepts';

-- ── Intro to IT questions ────────────────────────────────────────────────
insert into public.quiz_questions (quiz_id, question_text, question_type, options, correct_answer, explanation, sort_order)
select q.id, 'RAM is best described as:',
       'multiple_choice',
       '["Permanent storage","Volatile working memory","A network protocol","A type of CPU"]'::jsonb,
       'Volatile working memory',
       'RAM (Random Access Memory) loses its contents when power is removed — it''s where the OS and active programs run.', 1
from public.quizzes q where q.title = 'Intro to IT — Vocabulary' union all
select q.id, 'Which protocol is used to load web pages securely?',
       'multiple_choice',
       '["FTP","SMTP","HTTPS","SSH"]'::jsonb,
       'HTTPS',
       'HTTPS wraps HTTP in TLS so traffic is encrypted between browser and server.', 2
from public.quizzes q where q.title = 'Intro to IT — Vocabulary' union all
select q.id, 'A LAN is:',
       'multiple_choice',
       '["The public Internet","A small, local network","A wireless-only network","A type of firewall"]'::jsonb,
       'A small, local network',
       'LAN = Local Area Network, typically within one building.', 3
from public.quizzes q where q.title = 'Intro to IT — Vocabulary' union all
select q.id, 'What does CPU stand for?',
       'multiple_choice',
       '["Central Processing Unit","Computer Program Utility","Control Panel Unit","Cache Processing Unit"]'::jsonb,
       'Central Processing Unit',
       'The CPU is the chip that executes program instructions.', 4
from public.quizzes q where q.title = 'Intro to IT — Vocabulary' union all
select q.id, 'Which is an example of open-source software?',
       'multiple_choice',
       '["Microsoft Word","Adobe Photoshop","Linux","iOS"]'::jsonb,
       'Linux',
       'Linux source code is freely available under the GPL license.', 5
from public.quizzes q where q.title = 'Intro to IT — Vocabulary';

-- ── Economics questions ──────────────────────────────────────────────────
insert into public.quiz_questions (quiz_id, question_text, question_type, options, correct_answer, explanation, sort_order)
select q.id, 'When the price of a good rises, quantity demanded typically:',
       'multiple_choice',
       '["Rises","Falls","Stays the same","Doubles"]'::jsonb,
       'Falls',
       'This is the Law of Demand — an inverse relationship between price and quantity demanded.', 1
from public.quizzes q where q.title = 'Economics — Micro & Macro Basics' union all
select q.id, 'A good whose demand barely changes when price changes is called:',
       'multiple_choice',
       '["Elastic","Inelastic","Inferior","Luxury"]'::jsonb,
       'Inelastic',
       'Necessities like insulin have inelastic demand — quantity is insensitive to price.', 2
from public.quizzes q where q.title = 'Economics — Micro & Macro Basics' union all
select q.id, 'GDP measures:',
       'multiple_choice',
       '["Stock market value","Total goods & services produced","Unemployment rate","Government debt"]'::jsonb,
       'Total goods & services produced',
       'GDP = total market value of goods and services produced within a country in a period.', 3
from public.quizzes q where q.title = 'Economics — Micro & Macro Basics' union all
select q.id, 'The Federal Reserve can slow inflation by:',
       'multiple_choice',
       '["Cutting interest rates","Raising interest rates","Lowering taxes","Printing more money"]'::jsonb,
       'Raising interest rates',
       'Higher rates reduce borrowing and spending, cooling aggregate demand and inflation.', 4
from public.quizzes q where q.title = 'Economics — Micro & Macro Basics' union all
select q.id, 'A market with many sellers of identical products is called:',
       'multiple_choice',
       '["Monopoly","Oligopoly","Perfect competition","Monopolistic competition"]'::jsonb,
       'Perfect competition',
       'Perfect competition: many sellers, identical products, free entry/exit, perfect information.', 5
from public.quizzes q where q.title = 'Economics — Micro & Macro Basics';

-- ── Public Speaking questions ────────────────────────────────────────────
insert into public.quiz_questions (quiz_id, question_text, question_type, options, correct_answer, explanation, sort_order)
select q.id, 'What is the recommended structure of a classic speech?',
       'multiple_choice',
       '["Middle, beginning, end","Introduction, body, conclusion","Data, stories, jokes","Opinion, counterpoint, rebuttal"]'::jsonb,
       'Introduction, body, conclusion',
       'This is the textbook framework judges expect to see.', 1
from public.quizzes q where q.title = 'Public Speaking — Delivery Basics' union all
select q.id, 'Using filler words like "um" and "uh" excessively hurts:',
       'multiple_choice',
       '["Content","Delivery & credibility","Research","Citations"]'::jsonb,
       'Delivery & credibility',
       'Filler words are a delivery issue — they suggest lack of preparation.', 2
from public.quizzes q where q.title = 'Public Speaking — Delivery Basics' union all
select q.id, 'Making eye contact with different sections of the audience helps:',
       'multiple_choice',
       '["Fill time","Engage the audience","Hide the notes","Speed up the speech"]'::jsonb,
       'Engage the audience',
       'Eye contact builds connection, trust, and keeps attention.', 3
from public.quizzes q where q.title = 'Public Speaking — Delivery Basics' union all
select q.id, 'A pause at a key moment is useful for:',
       'multiple_choice',
       '["Emphasis","Hiding nerves","Wasting time","Drinking water"]'::jsonb,
       'Emphasis',
       'A well-placed pause lets an important point land and signals confidence.', 4
from public.quizzes q where q.title = 'Public Speaking — Delivery Basics' union all
select q.id, 'Which is the BEST way to start a speech?',
       'multiple_choice',
       '["Apologize for being nervous","Hook with a story, question, or stat","Read your title aloud","List your credentials"]'::jsonb,
       'Hook with a story, question, or stat',
       'A strong hook captures attention in the first 15 seconds.', 5
from public.quizzes q where q.title = 'Public Speaking — Delivery Basics';
