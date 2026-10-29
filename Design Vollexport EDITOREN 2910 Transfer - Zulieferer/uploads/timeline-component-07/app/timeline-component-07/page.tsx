import Process, {
  type ExperienceStep
} from '@/components/shadcn-studio/blocks/timeline-component-07/timeline-component-07'

const experienceSteps: ExperienceStep[] = [
  {
    id: '01',
    logo: 'https://cdn.shadcnstudio.com/ss-assets/template/landing-page/zolt/case-logo-01.png',
    company: 'Lumio',
    role: 'Design Engineer',
    period: '2025 - ',
    status: { text: 'Present', tone: 'positive' },
    stack: ['React', 'Figma', 'Design system', 'Tailwind'],
    achievement: 'Built a design system adopted by 4 product teams within 30 days',
    description:
      "Joined as the first design engineer on the team. Owned the entire design-to-code pipeline, built the product's design system from scratch, shipped new features weekly, and made sure nothing got lost between Figma and production."
  },
  {
    id: '02',
    logo: 'https://cdn.shadcnstudio.com/ss-assets/template/landing-page/zolt/case-logo-02.png',
    company: 'Trackflow HQ',
    role: 'Frontend Engineer + Designer',
    period: '2023 - 2024, 1 year',
    stack: ['React', 'Next.js', 'Figma', 'CSS', 'Component architecture'],
    achievement: 'Rebuilt the entire dashboard UI and cut user drop-off by 40%',
    description:
      'Started as a frontend engineer but quickly moved into a hybrid role. Rebuilt the core dashboard UI, reduced design inconsistencies across 30+ screens, and introduced component-based thinking to a team that had never used one.'
  },
  {
    id: '03',
    logo: 'https://cdn.shadcnstudio.com/ss-assets/template/landing-page/zolt/case-logo-03.png',
    company: 'Orion Labs',
    role: 'Freelance Design Engineer',
    period: '2023, 5 Months',
    stack: ['Framer', 'Motion design', 'Visual design', 'Copywriting'],
    achievement: 'Designed and shipped a full marketing site solo in under a week',
    description:
      'Brought in to design and build a launch marketing site before a funding announcement. Delivered a fully animated site in 5 days — design, build, and deployment handled solo.'
  },
  {
    id: '04',
    logo: 'https://cdn.shadcnstudio.com/ss-assets/template/landing-page/zolt/case-logo-04.png',
    company: 'Self-initiated',
    role: 'Side Projects & Open Source',
    period: '2022 - ',
    status: { text: 'Ongoing · Personal', tone: 'accent' },
    stack: ['React', 'Framer', 'TypeScript', 'Passion for building'],
    achievement: '3 shipped products with real users, 1 open source component library',
    description:
      'Built a component playground, a minimal habit tracker app, and a Chrome extension for designers. Where most of the real learning happens — no deadlines, no clients, just curiosity and craft.'
  }
]

const TimelinePage = () => {
  return <Process data={experienceSteps} />
}

export default TimelinePage
