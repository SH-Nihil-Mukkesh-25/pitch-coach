/// Data model for a communication lesson in the Learn section.
class Lesson {
  final String id;
  final String title;
  final String description;
  final String youtubeVideoId;
  final String videoUrl;
  final String duration;
  final String category; // 'interview' | 'presentation' | 'speaking'
  final String level; // 'beginner' | 'intermediate' | 'advanced'
  final List<String> takeaways;
  final String weakAreaTag; // maps to session result categories
  final String practiceExercise;
  final String keyVideoTimestamp;
  final String keyVideoTimestampEnd;
  final String keyVideoTimestampTip;
  final int timestampSeconds;

  const Lesson({
    required this.id,
    required this.title,
    required this.description,
    required this.youtubeVideoId,
    required this.videoUrl,
    required this.duration,
    required this.category,
    this.level = 'beginner',
    required this.takeaways,
    required this.weakAreaTag,
    this.practiceExercise =
        'Deliver a 60-second response focusing on clarity, structure, and eliminating fillers.',
    this.keyVideoTimestamp = '01:15',
    this.keyVideoTimestampEnd = '02:30',
    this.keyVideoTimestampTip =
        'Watch how the instructor structures their opening hook and delivers key points with composure.',
    this.timestampSeconds = 75,
  });

  String get levelLabel {
    if (level.isEmpty) return 'Beginner';
    return level[0].toUpperCase() + level.substring(1);
  }

  String get thumbnailUrl =>
      'https://img.youtube.com/vi/$youtubeVideoId/hqdefault.jpg';

  String get timestampVideoUrl =>
      'https://www.youtube.com/watch?v=$youtubeVideoId&t=${timestampSeconds}s';
}

/// Curated local lesson catalog for Pitch Coach.
/// 9 lessons per category (3 beginner, 3 intermediate, 3 advanced) = 27 total lessons.
abstract class LessonCatalog {
  static const List<Lesson> all = [
    // ══════════════════════════════════════════════════════════════════════
    // CORE FOUNDATIONS (Beginner entries across categories for top visibility)
    // ══════════════════════════════════════════════════════════════════════
    Lesson(
      id: 'l_int_01',
      title: 'Answer "Tell Me About Yourself"',
      description:
          'Craft a compelling, structured 2-minute answer to the most common interview opener using Richard McMunn\'s proven formula.',
      youtubeVideoId: 'VUzlCG_eoFs',
      videoUrl: 'https://www.youtube.com/watch?v=VUzlCG_eoFs',
      duration: '7 min',
      category: 'interview',
      level: 'beginner',
      weakAreaTag: 'confidence',
      practiceExercise:
          'Deliver your 90-second introduction using the 3-step formula: Current role & expertise -> Key workplace achievement -> Why this company excites you.',
      keyVideoTimestamp: '01:15',
      keyVideoTimestampEnd: '02:45',
      keyVideoTimestampTip:
          'Watch 01:15–02:45 to see Richard McMunn demonstrate how to hook the interviewer within the opening seconds without reciting your resume.',
      timestampSeconds: 75,
      takeaways: [
        'Use Richard McMunn\'s 3-step framework to structure your introduction',
        'Directly connect your past achievements to the target role',
        'Keep your delivery strictly under 2 minutes with high energy',
        'Conclude with authentic enthusiasm about why you want this job',
      ],
    ),
    Lesson(
      id: 'l_pres_01',
      title: 'Presentation Body Language',
      description:
          'Learn Richard McMunn\'s 8 core body language techniques: upright posture, open hand gestures, and steady eye contact.',
      youtubeVideoId: 'Go4GVvcS02Y',
      videoUrl: 'https://www.youtube.com/watch?v=Go4GVvcS02Y',
      duration: '9 min',
      category: 'presentation',
      level: 'beginner',
      weakAreaTag: 'confidence',
      practiceExercise:
          'Present a 60-second statement using open palm gestures, upright spine, balanced weight, and steady eye contact with the camera.',
      keyVideoTimestamp: '01:10',
      keyVideoTimestampEnd: '02:30',
      keyVideoTimestampTip:
          'Watch 01:10–02:30 to observe Richard McMunn\'s 8 body language rules to project warmth, confidence, and executive presence.',
      timestampSeconds: 70,
      takeaways: [
        'Sit tall and upright with open shoulders — never slouch or cross arms defensively',
        'Use gentle open-palm hand gestures on the desk to project honesty and engagement',
        'Maintain natural, relaxed eye contact (60-70% of the conversation)',
        'Nod periodically while listening to show active engagement and respect',
      ],
    ),
    Lesson(
      id: 'l_spk_01',
      title: 'Reduce Filler Words',
      description:
          'Learn how to speak clearly without relying on unnecessary filler words like "um", "uh", or "like".',
      youtubeVideoId: 'zM0gAd2SjPA',
      videoUrl: 'https://www.youtube.com/watch?v=zM0gAd2SjPA',
      duration: '4 min',
      category: 'speaking',
      level: 'beginner',
      weakAreaTag: 'filler_words',
      practiceExercise:
          'Speak for 60 seconds about your morning routine. Replace every single "um", "uh", or "like" with a conscious silent breath.',
      keyVideoTimestamp: '01:00',
      keyVideoTimestampEnd: '02:15',
      keyVideoTimestampTip:
          'Watch 01:00–02:15 to practice the replacement habit: Inhale silently whenever your brain searches for the next word.',
      timestampSeconds: 60,
      takeaways: [
        'Pause and inhale instead of voicing an automatic "um"',
        'Prepare smooth sentence transition words in advance',
        'Slow down naturally — deliberate silence signals composure',
        'Review your session transcripts to discover your filler triggers',
      ],
    ),
    Lesson(
      id: 'l_spk_02',
      title: 'Control Your Speaking Pace',
      description:
          'Master Richard McMunn\'s techniques to speak fluently and calmly without stammering, rushing, or losing your flow.',
      youtubeVideoId: 'w28JEwRwE7E',
      videoUrl: 'https://www.youtube.com/watch?v=w28JEwRwE7E',
      duration: '14 min',
      category: 'speaking',
      level: 'beginner',
      weakAreaTag: 'pacing',
      practiceExercise:
          'Deliver a 60-second answer at a measured 130–140 WPM, taking deliberate micro-pauses at each punctuation stop.',
      keyVideoTimestamp: '01:50',
      keyVideoTimestampEnd: '03:20',
      keyVideoTimestampTip:
          'Watch 01:50–03:20 to see Richard McMunn\'s practical exercises for speaking fluently and eliminating hesitation.',
      timestampSeconds: 110,
      takeaways: [
        'Slow down your cadence to 130–150 words per minute to give your brain processing time',
        'Insert brief silent pauses at sentence boundaries instead of rushing to fill the gap',
        'Enunciate ending consonants crisply to command listener attention',
        'Practice answering questions aloud every day to develop fluent muscle memory',
      ],
    ),
    Lesson(
      id: 'l_spk_03',
      title: 'Pause for Emphasis',
      description:
          'Master the art of strategic pausing to add impact, clarity, and confidence to your speech.',
      youtubeVideoId: 'WkS67oiei78',
      videoUrl: 'https://www.youtube.com/watch?v=WkS67oiei78',
      duration: '3 min',
      category: 'speaking',
      level: 'beginner',
      weakAreaTag: 'pacing',
      practiceExercise:
          'Deliver 3 important statements, taking a full 2-second pause right before the headline word and a 2-second silence after.',
      keyVideoTimestamp: '00:55',
      keyVideoTimestampEnd: '02:10',
      keyVideoTimestampTip:
          'Watch 00:55–02:10 to observe how strategic pauses create dramatic anticipation in the listener\'s mind.',
      timestampSeconds: 55,
      takeaways: [
        'A pause demonstrates intellectual mastery, not hesitation',
        'Insert a brief 1-second pause right before headline insights',
        'Allow 2-3 seconds of silence after major rhetorical questions',
        'Give listeners time to absorb and internalize complex ideas',
      ],
    ),

    // ── Additional Beginner Lessons ─────────────────────────────────────────
    Lesson(
      id: 'l_int_02',
      title: 'How To Introduce Yourself In An Interview',
      description:
          'Master Richard McMunn\'s proven formula to introduce yourself in an interview with warmth, poise, and credibility.',
      youtubeVideoId: 'wexzvClUcUk',
      videoUrl: 'https://www.youtube.com/watch?v=wexzvClUcUk',
      duration: '5 min',
      category: 'interview',
      level: 'beginner',
      weakAreaTag: 'confidence',
      practiceExercise:
          'Deliver your 60-second introduction highlighting your background, work ethic, and why you are excited for this opportunity.',
      keyVideoTimestamp: '01:10',
      keyVideoTimestampEnd: '02:25',
      keyVideoTimestampTip:
          'Watch 01:10–02:25 to see Richard McMunn demonstrate the ideal blend of professional competence and friendly warmth.',
      timestampSeconds: 70,
      takeaways: [
        'Maintain upright posture and a warm, natural smile from the first greeting',
        'Open with your name and a concise overview of your professional domain',
        'Highlight 2 core qualities that make you a reliable, positive teammate',
        'Keep your introductory greeting focused and strictly under 90 seconds',
      ],
    ),
    Lesson(
      id: 'l_int_03',
      title: 'Why Do You Want This Role?',
      description:
          'Align your personal motivations directly with the company\'s culture and commercial goals using Richard McMunn\'s 3-pillar method.',
      youtubeVideoId: '6OW2QIzg4VI',
      videoUrl: 'https://www.youtube.com/watch?v=6OW2QIzg4VI',
      duration: '6 min',
      category: 'interview',
      level: 'beginner',
      weakAreaTag: 'clarity',
      practiceExercise:
          'Cite 2 specific company initiatives or values and explain how your experience will solve their immediate priorities.',
      keyVideoTimestamp: '01:20',
      keyVideoTimestampEnd: '02:45',
      keyVideoTimestampTip:
          'Watch 01:20–02:45 to see Richard McMunn\'s formula for proving you researched the company and genuinely want this role.',
      timestampSeconds: 80,
      takeaways: [
        'Cite 2-3 specific initiatives or achievements the company recently announced',
        'Explain how your skills directly solve their immediate problems',
        'Avoid self-centered answers focusing only on pay, perks, or commute',
        'Express authentic enthusiasm for long-term growth with the team',
      ],
    ),
    Lesson(
      id: 'l_pres_02',
      title: 'Designing Clean, Impactful Slides',
      description:
          'Apply visual hierarchy, white space, and the one-idea-per-slide rule to eliminate audience cognitive overload.',
      youtubeVideoId: '8d94BIvF6ZQ',
      videoUrl: 'https://www.youtube.com/watch?v=8d94BIvF6ZQ',
      duration: '4 min',
      category: 'presentation',
      level: 'beginner',
      weakAreaTag: 'clarity',
      practiceExercise:
          'Describe a single complex project slide using the "one core idea" rule and explain the visual hierarchy you would use.',
      keyVideoTimestamp: '01:40',
      keyVideoTimestampEnd: '02:55',
      keyVideoTimestampTip:
          'Watch 01:40–02:55 to avoid cognitive overload by using white space and bold focal points.',
      timestampSeconds: 100,
      takeaways: [
        'Enforce the 1-core-idea per slide rule strictly',
        'Use generous margins and minimum 24pt legible typography',
        'Replace long bullet paragraphs with clear visual icons or callouts',
        'Let your slides support your words rather than script them',
      ],
    ),
    Lesson(
      id: 'l_pres_03',
      title: 'Hooking Your Audience in 60 Seconds',
      description:
          'Replace boring agenda slides with a compelling narrative hook, striking statistic, or thought-provoking question.',
      youtubeVideoId: '_CnXi51MTLQ',
      videoUrl: 'https://www.youtube.com/watch?v=_CnXi51MTLQ',
      duration: '4 min',
      category: 'presentation',
      level: 'beginner',
      weakAreaTag: 'energy',
      practiceExercise:
          'Open a presentation with a startling statistic or real human story that immediately creates curiosity and urgency.',
      keyVideoTimestamp: '00:50',
      keyVideoTimestampEnd: '02:00',
      keyVideoTimestampTip:
          'Watch 00:50–02:00 to see 3 proven hooks that grab 100% of the room within the first 30 seconds.',
      timestampSeconds: 50,
      takeaways: [
        'Never begin with "Today I will present about..."',
        'Start with a startling statistic or a real human problem',
        'State the direct benefit the audience will gain by listening',
        'Project high vocal energy right from the very first syllable',
      ],
    ),

    // ══════════════════════════════════════════════════════════════════════
    // INTERMEDIATE LESSONS
    // ══════════════════════════════════════════════════════════════════════
    Lesson(
      id: 'l_int_04',
      title: 'The STAR Method for Behavioral Questions',
      description:
          'Structure high-scoring behavioral answers using Richard McMunn\'s STAR method (Situation, Task, Action, and measurable Results).',
      youtubeVideoId: 'uQEuo7woEEk',
      videoUrl: 'https://www.youtube.com/watch?v=uQEuo7woEEk',
      duration: '11 min',
      category: 'interview',
      level: 'intermediate',
      weakAreaTag: 'structure',
      practiceExercise:
          'Answer: "Tell me about a high-pressure situation you resolved." Dedicate 20% to Situation/Task, 60% to your Actions, and 20% to measurable Results.',
      keyVideoTimestamp: '01:45',
      keyVideoTimestampEnd: '03:20',
      keyVideoTimestampTip:
          'Watch 01:45–03:20 to see Richard McMunn break down each letter of the STAR technique with winning example answers.',
      timestampSeconds: 105,
      takeaways: [
        'Situation: Briefly describe the context and background (20% of your answer)',
        'Task: Define the challenge or responsibility you needed to address',
        'Action: Detail the step-by-step actions YOU personally took (60% of your answer)',
        'Result: Conclude with quantifiable numbers, client praise, or positive outcomes (20%)',
      ],
    ),
    Lesson(
      id: 'l_int_05',
      title: 'What Are Your Strengths & Weaknesses?',
      description:
          'Turn questions about strengths and weaknesses into authentic demonstrations of competence and self-awareness.',
      youtubeVideoId: 'CPexmL0FNaw',
      videoUrl: 'https://www.youtube.com/watch?v=CPexmL0FNaw',
      duration: '14 min',
      category: 'interview',
      level: 'intermediate',
      weakAreaTag: 'confidence',
      practiceExercise:
          'Deliver a 60-second response detailing a genuine professional weakness and the proactive system you built to overcome it.',
      keyVideoTimestamp: '02:10',
      keyVideoTimestampEnd: '03:40',
      keyVideoTimestampTip:
          'Watch 02:10–03:40 to see Richard McMunn explain how to discuss weaknesses without damaging your candidacy.',
      timestampSeconds: 130,
      takeaways: [
        'Choose a genuine, non-critical weakness and describe how you are actively fixing it',
        'Back up your strengths with tangible evidence and past workplace achievements',
        'Avoid humblebrags like "I work too hard" or "I care too much"',
        'Demonstrate coachability, emotional maturity, and self-reflection',
      ],
    ),
    Lesson(
      id: 'l_int_06',
      title: 'Questions to Ask at the End of an Interview',
      description:
          'Transform the end of the interview into a memorable strategic dialogue using Richard McMunn\'s top recommended questions.',
      youtubeVideoId: '2u_5Lyz6TCA',
      videoUrl: 'https://www.youtube.com/watch?v=2u_5Lyz6TCA',
      duration: '3 min',
      category: 'interview',
      level: 'intermediate',
      weakAreaTag: 'clarity',
      practiceExercise:
          'Pose 2 strategic end-of-interview questions about 90-day success metrics and team growth opportunities.',
      keyVideoTimestamp: '00:45',
      keyVideoTimestampEnd: '02:00',
      keyVideoTimestampTip:
          'Watch 00:45–02:00 to learn Richard McMunn\'s top 5 questions that impress hiring managers and leave a lasting impression.',
      timestampSeconds: 45,
      takeaways: [
        'Ask: "What advice would you give to the successful candidate to excel in this role?"',
        'Inquire about the biggest team priorities over the next 6 to 12 months',
        'Ask the interviewers what they personally enjoy most about working there',
        'Never ask about salary, bonuses, or vacation days during the first round',
      ],
    ),
    Lesson(
      id: 'l_pres_04',
      title: 'Story Arc & Narrative Decks',
      description:
          'Transform dry data reports into a compelling narrative using the Status Quo -> Conflict -> Resolution framework.',
      youtubeVideoId: 'hNuAv-42jzY',
      videoUrl: 'https://www.youtube.com/watch?v=hNuAv-42jzY',
      duration: '5 min',
      category: 'presentation',
      level: 'intermediate',
      weakAreaTag: 'structure',
      practiceExercise:
          'Pitch a solution using the Story Arc: 1) The pain of the Status Quo, 2) The Conflict, 3) The Transformative Resolution.',
      keyVideoTimestamp: '02:00',
      keyVideoTimestampEnd: '03:30',
      keyVideoTimestampTip:
          'Watch 02:00–03:30 to see how narrative tension keeps audiences emotionally invested until the final slide.',
      timestampSeconds: 120,
      takeaways: [
        'Make the audience or customer the hero of the narrative',
        'Clarify the stakes: what happens if no action is taken?',
        'Present your solution as the transformative catalyst',
        'End on an inspiring call-to-action that creates immediate urgency',
      ],
    ),
    Lesson(
      id: 'l_pres_05',
      title: 'Virtual Meeting Presentation Mastery',
      description:
          'Keep Zoom and Teams audiences engaged through strategic check-ins, vocal dynamics, and screen-sharing best practices.',
      youtubeVideoId: '5bsrPN5xGTE',
      videoUrl: 'https://www.youtube.com/watch?v=5bsrPN5xGTE',
      duration: '4 min',
      category: 'presentation',
      level: 'intermediate',
      weakAreaTag: 'energy',
      practiceExercise:
          'Deliver a 60-second virtual presentation update while looking straight into the camera lens and varying your vocal dynamics.',
      keyVideoTimestamp: '01:15',
      keyVideoTimestampEnd: '02:30',
      keyVideoTimestampTip:
          'Watch 01:15–02:30 to learn how to keep remote attendees engaged without screen fatigue.',
      timestampSeconds: 75,
      takeaways: [
        'Look directly into the camera lens when emphasizing key claims',
        'Incorporate an interactive question or poll every 3-4 minutes',
        'Vary your vocal pitch more than you would in person to prevent fatigue',
        'Use spotlight cursors or annotations to direct visual attention',
      ],
    ),
    Lesson(
      id: 'l_pres_06',
      title: 'Delivering Complex Metrics & Data',
      description:
          'Translate complicated spreadsheets and technical architecture into digestible, executive-ready insights.',
      youtubeVideoId: '8EMW7io4rSI',
      videoUrl: 'https://www.youtube.com/watch?v=8EMW7io4rSI',
      duration: '5 min',
      category: 'presentation',
      level: 'intermediate',
      weakAreaTag: 'clarity',
      practiceExercise:
          'Present a quarterly performance metric: State the number, contextualize against the baseline goal, and explain the business consequence.',
      keyVideoTimestamp: '02:15',
      keyVideoTimestampEnd: '03:45',
      keyVideoTimestampTip:
          'Watch 02:15–03:45 to see how to translate spreadsheets into simple, executive-ready insights.',
      timestampSeconds: 135,
      takeaways: [
        'Spotlight the single metric that matters most to decision-makers',
        'Always contextualize data against baseline targets or historical trends',
        'Use color sparingly to draw eyes directly to critical anomalies',
        'State the business consequence of the data: "What this means is..."',
      ],
    ),
    Lesson(
      id: 'l_spk_04',
      title: 'Vocal Variety & Tone Modulation',
      description:
          'Break free from monotone delivery by infusing pitch changes, emotional inflection, and volume shifts.',
      youtubeVideoId: 'eIho2S0ZahI',
      videoUrl: 'https://www.youtube.com/watch?v=eIho2S0ZahI',
      duration: '5 min',
      category: 'speaking',
      level: 'intermediate',
      weakAreaTag: 'energy',
      practiceExercise:
          'Speak a passage alternating between energetic excitement, warm empathy, and serious authority. Avoid a flat monotone.',
      keyVideoTimestamp: '02:05',
      keyVideoTimestampEnd: '03:20',
      keyVideoTimestampTip:
          'Watch 02:05–03:20 to see how Julian Treasure shifts pitch, timbre, and pace to keep ears completely locked in.',
      timestampSeconds: 125,
      takeaways: [
        'Identify and emphasize 1-2 operative words in every sentence',
        'Lower your vocal pitch slightly at period endings to sound decisive',
        'Elevate volume dynamically during breakthrough points',
        'Infuse conversational warmth during narrative illustrations',
      ],
    ),
    Lesson(
      id: 'l_spk_05',
      title: 'Diaphragmatic Breath & Projection',
      description:
          'Eliminate breathlessness, voice tremors, and throat strain with deep belly-breathing techniques.',
      youtubeVideoId: '5Oe133AKXj0',
      videoUrl: 'https://www.youtube.com/watch?v=5Oe133AKXj0',
      duration: '4 min',
      category: 'speaking',
      level: 'intermediate',
      weakAreaTag: 'confidence',
      practiceExercise:
          'Place one hand on your belly, inhale deep into your diaphragm, and speak a 15-second sentence on a steady, resonant exhale.',
      keyVideoTimestamp: '01:10',
      keyVideoTimestampEnd: '02:25',
      keyVideoTimestampTip:
          'Watch 01:10–02:25 to learn how belly breathing eliminates voice tremors and throat strain.',
      timestampSeconds: 70,
      takeaways: [
        'Breathe deep into the lower abdomen rather than shallow in the chest',
        'Speak smoothly on the exhale to maintain stable vocal cord support',
        'Reset your posture and breath whenever you feel speaking tension',
        'Warm up your vocal cords with gentle humming before long talks',
      ],
    ),
    Lesson(
      id: 'l_spk_06',
      title: 'Crisp Articulation & Diction',
      description:
          'Overcome mumbled speech and slurred syllables with targeted tongue and jaw articulation warmups.',
      youtubeVideoId: 'hAbPvemD08A',
      videoUrl: 'https://www.youtube.com/watch?v=hAbPvemD08A',
      duration: '4 min',
      category: 'speaking',
      level: 'intermediate',
      weakAreaTag: 'clarity',
      practiceExercise:
          'Clearly enunciate the ending consonants of every word: "Exact project impact requires distinct performance targets."',
      keyVideoTimestamp: '01:15',
      keyVideoTimestampEnd: '02:30',
      keyVideoTimestampTip:
          'Watch 01:15–02:30 to practice tongue and jaw warmups that eliminate mumbled syllables.',
      timestampSeconds: 75,
      takeaways: [
        'Crisply enunciate ending consonants (T, D, P, K) to avoid slurring',
        'Open your jaw sufficiently to allow rich vowel resonance',
        'Practice 2-minute daily tongue twisters before major recordings',
        'Relax facial muscles to prevent tension from constricting words',
      ],
    ),

    // ══════════════════════════════════════════════════════════════════════
    // ADVANCED LESSONS
    // ══════════════════════════════════════════════════════════════════════
    Lesson(
      id: 'l_int_07',
      title: 'Executive Presence in Case Interviews',
      description:
          'Communicate vision, team empowerment, and conflict resolution like an executive using Richard McMunn\'s leadership framework.',
      youtubeVideoId: 'Fj8TzmUzkFc',
      videoUrl: 'https://www.youtube.com/watch?v=Fj8TzmUzkFc',
      duration: '13 min',
      category: 'interview',
      level: 'advanced',
      weakAreaTag: 'structure',
      practiceExercise:
          'Explain how you lead through adversity: Describe how you supported your team, resolved a bottleneck, and delivered on target.',
      keyVideoTimestamp: '02:15',
      keyVideoTimestampEnd: '03:45',
      keyVideoTimestampTip:
          'Watch 02:15–03:45 to see Richard McMunn model the calm, authoritative tone expected of senior leaders.',
      timestampSeconds: 135,
      takeaways: [
        'Lead by example: emphasize personal accountability and supportive mentorship',
        'Highlight how you communicate clear expectations and delegate effectively',
        'Explain how you resolve interpersonal conflicts calmly and constructively',
        'Share how you make tough, data-backed decisions during tight deadlines',
      ],
    ),
    Lesson(
      id: 'l_int_08',
      title: 'Salary Negotiation & Expectations',
      description:
          'Anchor your compensation discussions professionally and negotiate top-of-market compensation with Richard McMunn\'s 5 tips.',
      youtubeVideoId: 'z0lpdfzgNdE',
      videoUrl: 'https://www.youtube.com/watch?v=z0lpdfzgNdE',
      duration: '8 min',
      category: 'interview',
      level: 'advanced',
      weakAreaTag: 'confidence',
      practiceExercise:
          'Deliver your salary expectation response: State your target range backed by industry market research and focus on value delivery.',
      keyVideoTimestamp: '01:40',
      keyVideoTimestampEnd: '03:10',
      keyVideoTimestampTip:
          'Watch 01:40–03:10 to learn Richard McMunn\'s collaborative phrasing that protects your market value without creating friction.',
      timestampSeconds: 100,
      takeaways: [
        'Research benchmark salary ranges for your role and region before the interview',
        'Reiterate that value contribution and long-term fit are your top priorities',
        'Offer a realistic salary range rather than boxing yourself into a single number',
        'Politely negotiate the entire compensation package after an offer is extended',
      ],
    ),
    Lesson(
      id: 'l_int_09',
      title: 'Passing the Hardest Interview Questions',
      description:
          'Stay calm and composed under aggressive pushback and tricky prompts using Richard McMunn\'s top-scoring strategies.',
      youtubeVideoId: 'WOHFlwYV210',
      videoUrl: 'https://www.youtube.com/watch?v=WOHFlwYV210',
      duration: '12 min',
      category: 'interview',
      level: 'advanced',
      weakAreaTag: 'pacing',
      practiceExercise:
          'Take a 2-second breath, address a difficult scenario prompt, and deliver a structured, solution-oriented response.',
      keyVideoTimestamp: '02:00',
      keyVideoTimestampEnd: '03:30',
      keyVideoTimestampTip:
          'Watch 02:00–03:30 to see how Richard McMunn uses deliberate pauses to stay composed during high-stakes questioning.',
      timestampSeconds: 120,
      takeaways: [
        'Take a 2-second silent breath before speaking to organize your thoughts',
        'Acknowledge complexity without showing frustration or defensive body language',
        'Structure your response clearly: context, strategic action, positive result',
        'Maintain an even vocal pitch and confident posture under pressure',
      ],
    ),
    Lesson(
      id: 'l_pres_07',
      title: 'Job & Executive Presentation Mastery',
      description:
          'Structure and deliver a compelling presentation in an interview or executive meeting with Richard McMunn\'s proven formula.',
      youtubeVideoId: 'P-fHw3WAgNQ',
      videoUrl: 'https://www.youtube.com/watch?v=P-fHw3WAgNQ',
      duration: '15 min',
      category: 'presentation',
      level: 'advanced',
      weakAreaTag: 'confidence',
      practiceExercise:
          'Deliver a 90-second executive presentation opening outlining your 30-60-90 day impact roadmap.',
      keyVideoTimestamp: '02:30',
      keyVideoTimestampEnd: '04:00',
      keyVideoTimestampTip:
          'Watch 02:30–04:00 to see Richard McMunn walk through an actual interview presentation template slide by slide.',
      timestampSeconds: 150,
      takeaways: [
        'Structure clearly: Introduction, Understanding the Role, 30-60-90 Day Plan, Summary',
        'Keep slides visually clean with key bullet points rather than wordy paragraphs',
        'Focus on actionable solutions that solve the employer\'s biggest current challenges',
        'Conclude with conviction on why your skills make you the highest-value hire',
      ],
    ),
    Lesson(
      id: 'l_pres_08',
      title: 'Persuasive Pitching & Closing the Ask',
      description:
          'Craft an irresistible final pitch slide that asks for budget, approval, or investment with clarity and confidence.',
      youtubeVideoId: 'qp0HIF3SfI4',
      videoUrl: 'https://www.youtube.com/watch?v=qp0HIF3SfI4',
      duration: '6 min',
      category: 'presentation',
      level: 'advanced',
      weakAreaTag: 'structure',
      practiceExercise:
          'Deliver your closing slide pitch: Clearly state the exact ask (budget/headcount), highlight the ROI, and outline next steps.',
      keyVideoTimestamp: '02:20',
      keyVideoTimestampEnd: '03:50',
      keyVideoTimestampTip:
          'Watch 02:20–03:50 to master closing the ask with conviction and clear next milestones.',
      timestampSeconds: 140,
      takeaways: [
        'Quantify the specific ask: dollar amount, headcount, or sign-off',
        'Contrast the projected ROI against the ongoing cost of inaction',
        'Preemptively address the top two perceived risks and mitigations',
        'Conclude with a clear roadmap of immediate next milestones',
      ],
    ),
    Lesson(
      id: 'l_pres_09',
      title: 'Keynote Stage Presence & Command',
      description:
          'Command large auditorium stages with deliberate stage movement, micro-pauses, and theatrical vocal resonance.',
      youtubeVideoId: 'Ks-_Mh1QhMc',
      videoUrl: 'https://www.youtube.com/watch?v=Ks-_Mh1QhMc',
      duration: '7 min',
      category: 'presentation',
      level: 'advanced',
      weakAreaTag: 'energy',
      practiceExercise:
          'Deliver a 60-second auditorium keynote intro with powerful diaphragmatic voice projection and a 3-second strategic opening silence.',
      keyVideoTimestamp: '01:30',
      keyVideoTimestampEnd: '02:50',
      keyVideoTimestampTip:
          'Watch 01:30–02:50 to see how world-class keynote speakers use silence and grounded footing to hold large stages.',
      timestampSeconds: 90,
      takeaways: [
        'Plant your feet firmly when delivering core statements',
        'Move deliberately between distinct stage areas for each chapter',
        'Harness 3-second strategic silences to create magnetic anticipation',
        'Speak from your diaphragm for rich, resonant acoustic authority',
      ],
    ),
    Lesson(
      id: 'l_spk_07',
      title: 'Impromptu Speaking & The PREP Method',
      description:
          'Answer off-the-cuff questions flawlessly using Point, Reason, Example, and Point restatement.',
      youtubeVideoId: 'Ug3YAXShnvs',
      videoUrl: 'https://www.youtube.com/watch?v=Ug3YAXShnvs',
      duration: '5 min',
      category: 'speaking',
      level: 'advanced',
      weakAreaTag: 'structure',
      practiceExercise:
          'Answer off-the-cuff: "Should remote work be permanent?" Use PREP: Point -> Reason -> Example -> Point.',
      keyVideoTimestamp: '01:45',
      keyVideoTimestampEnd: '03:10',
      keyVideoTimestampTip:
          'Watch 01:45–03:10 to master the PREP framework so you never get caught off-guard in impromptu meetings.',
      timestampSeconds: 105,
      takeaways: [
        'Deliver your core Point immediately in your opening sentence',
        'Provide the overarching strategic Reason backing your stance',
        'Share a concrete, memorable Example illustrating that rationale',
        'Restate your bottom-line Point with conclusive finality',
      ],
    ),
    Lesson(
      id: 'l_spk_08',
      title: 'Overcoming Interview Nerves & Speaking with Confidence',
      description:
          'Learn Richard McMunn\'s 11 practical tips to conquer interview anxiety, calm adrenaline, and project self-assurance.',
      youtubeVideoId: 'lKCTS9dY4h4',
      videoUrl: 'https://www.youtube.com/watch?v=lKCTS9dY4h4',
      duration: '12 min',
      category: 'speaking',
      level: 'advanced',
      weakAreaTag: 'confidence',
      practiceExercise:
          'Practice 4-7-8 deep breathing for 20 seconds, relax your shoulders, and deliver an assertive 60-second introduction.',
      keyVideoTimestamp: '01:30',
      keyVideoTimestampEnd: '03:00',
      keyVideoTimestampTip:
          'Watch 01:30–03:00 to see Richard McMunn\'s 11 actionable strategies to turn nervous anxiety into positive energy.',
      timestampSeconds: 90,
      takeaways: [
        'Reframe physical nervousness as excitement and peak readiness to perform',
        'Take slow, deep breaths from your abdomen before entering the room or call',
        'Remember the interview is a mutual conversation, not an interrogation',
        'Over-prepare your opening 90 seconds to establish instant momentum and confidence',
      ],
    ),
    Lesson(
      id: 'l_spk_09',
      title: 'Persuasive Rhetoric & Cadence Mastery',
      description:
          'Leverage classical rhetorical devices — tricolon (rule of three), anaphora, and contrasting cadence.',
      youtubeVideoId: '6fHoN6MR6MI',
      videoUrl: 'https://www.youtube.com/watch?v=6fHoN6MR6MI',
      duration: '6 min',
      category: 'speaking',
      level: 'advanced',
      weakAreaTag: 'energy',
      practiceExercise:
          'Use the Rule of Three (tricolon) to explain a vision: "We must adapt quickly, build boldly, and lead decisively."',
      keyVideoTimestamp: '02:10',
      keyVideoTimestampEnd: '03:35',
      keyVideoTimestampTip:
          'Watch 02:10–03:35 to see how rhythmic triads and parallel cadence create unforgettable closing statements.',
      timestampSeconds: 130,
      takeaways: [
        'Group ideas into rhythmic triads (rule of three) for memorability',
        'Use repeated opening phrases (anaphora) to build emotional momentum',
        'Alternate punchy short sentences with expansive, detailed thoughts',
        'Finish speeches on an uplifting, rhythmic cadence that lingers',
      ],
    ),
  ];

  /// Returns the most relevant lesson for a weak area tag.
  static Lesson? forWeakArea(String tag) {
    try {
      return all.firstWhere((l) => l.weakAreaTag == tag);
    } catch (_) {
      return null;
    }
  }

  static List<Lesson> byCategory(String category) =>
      all.where((l) => l.category == category.toLowerCase()).toList();

  static List<Lesson> byLevel(String level) =>
      all.where((l) => l.level == level.toLowerCase()).toList();

  static List<Lesson> byCategoryAndLevel(String category, String level) {
    final cat = category.toLowerCase();
    final lvl = level.toLowerCase();
    return all.where((l) {
      final matchCat = cat == 'all' || l.category == cat;
      final matchLvl = lvl == 'all' || l.level == lvl;
      return matchCat && matchLvl;
    }).toList();
  }
}
