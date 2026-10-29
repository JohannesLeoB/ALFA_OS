import { Badge } from '@/components/ui/badge'
import { TimelineAnimate } from '@/components/ui/timeline-animate'

import { cn } from '@/lib/utils'

export interface ExperienceStep {
  id: string
  logo: string
  company: string
  role: string
  period: string
  status?: { text: string; tone: 'positive' | 'accent' }
  stack: string[]
  achievement: string
  description: string
}

const ExperienceCard = ({
  logo,
  company,
  role,
  period,
  status,
  stack,
  achievement,
  description
}: Omit<ExperienceStep, 'id'>) => {
  return (
    <div className='space-y-4'>
      <div className='mb-2 flex gap-3 sm:items-center'>
        <div className='bg-muted flex size-12 shrink-0 items-center justify-center rounded-md sm:size-13.5'>
          <img src={logo} alt={`${company} logo`} loading='lazy' className='size-8 sm:size-9' />
        </div>
        <div>
          <p className='text-muted-foreground text-sm'>{company}</p>
          <h3 className='text-lg font-semibold sm:text-2xl'>{role}</h3>
        </div>
      </div>

      <div className='space-y-3 text-sm sm:text-base'>
        <p className='flex items-center gap-2'>
          <img
            src='https://cdn.shadcnstudio.com/ss-assets/template/landing-page/zolt/calendar.png'
            alt='calendar'
            className='size-6'
          />
          <span>
            {period}
            {status && (
              <span
                className={cn(
                  'ml-1 font-medium',
                  status.tone === 'positive'
                    ? 'text-green-600 dark:text-green-400'
                    : 'text-amber-600 dark:text-amber-400'
                )}
              >
                {status.text}
              </span>
            )}
          </span>
        </p>

        <div className='flex gap-2 sm:items-center'>
          <img
            src='https://cdn.shadcnstudio.com/ss-assets/template/landing-page/zolt/medal.png'
            alt='Medal'
            className='size-6'
          />
          <div className='flex flex-wrap items-center gap-2'>
            {stack.map(tech => (
              <Badge key={tech} variant='secondary' className='text-foreground bg-muted h-5.5 rounded-full'>
                {tech}
              </Badge>
            ))}
          </div>
        </div>

        <p className='flex items-start gap-2 font-medium'>
          <img
            src='https://cdn.shadcnstudio.com/ss-assets/template/landing-page/zolt/speaker.png'
            alt='speaker'
            className='size-6'
          />
          <span className='text-base font-medium'>{achievement}</span>
        </p>
      </div>

      <p className='text-muted-foreground max-w-145'>{description}</p>
    </div>
  )
}

const Process = ({ data }: { data: ExperienceStep[] }) => {
  return (
    <section className='mt-20 mb-75 py-8 sm:py-16 lg:py-24'>
      <div className='mx-auto max-w-3xl space-y-8 px-4 sm:px-6 lg:space-y-8 lg:px-8'>
        <div className='space-y-2'>
          <p className='text-primary text-lg font-medium italic sm:text-xl'>{'// Stacks & Experience'}</p>
          <h2 className='text-2xl font-semibold sm:text-3xl lg:text-4xl'>
            Where i&apos;m good and where i learned from
          </h2>
        </div>
        <TimelineAnimate
          data={data.map(({ id, ...step }) => ({
            index: id,
            content: <ExperienceCard {...step} />
          }))}
        />
      </div>
    </section>
  )
}

export default Process
