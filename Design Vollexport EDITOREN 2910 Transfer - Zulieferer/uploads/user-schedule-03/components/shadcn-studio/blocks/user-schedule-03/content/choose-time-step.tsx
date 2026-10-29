'use client'

// React Imports
import { useEffect, useRef } from 'react'
import type { ComponentProps } from 'react'

// Third-party Imports
import { getDay, isAfter, startOfDay } from 'date-fns'

// Component Imports
import { Button } from '@/components/ui/button'
import { Calendar, CalendarDayButton } from '@/components/ui/calendar'
import { cn } from '@/lib/utils'

const MORNING_SLOTS = ['9:00 AM', '9:30 AM', '10:00 AM', '10:30 AM', '11:00 AM', '11:30 AM']

const AFTERNOON_SLOTS = [
  '12:00 PM',
  '12:30 PM',
  '1:00 PM',
  '1:30 PM',
  '2:00 PM',
  '2:30 PM',
  '3:00 PM',
  '3:30 PM',
  '4:00 PM',
  '4:30 PM',
  '5:00 PM',
  '5:30 PM'
]

const isBookableDate = (date: Date) => isAfter(startOfDay(date), startOfDay(new Date())) && getDay(date) !== 0

const AvailabilityDayButton = ({ modifiers, day, children, ...props }: ComponentProps<typeof CalendarDayButton>) => {
  return (
    <CalendarDayButton day={day} modifiers={modifiers} {...props}>
      <span>{children}</span>
      <span
        className={cn('size-1 rounded-full', {
          'bg-transparent': !modifiers.available,
          'bg-orange-600 dark:bg-orange-400': modifiers.available && !modifiers.selected,
          'bg-primary-foreground': modifiers.available && modifiers.selected
        })}
      />
    </CalendarDayButton>
  )
}

type ChooseTimeStepProps = {
  selectedDate: Date | undefined
  onSelectDate: (date: Date | undefined) => void
  selectedTime: string | null
  onSelectTime: (time: string) => void
}

const ChooseTimeStep = ({ selectedDate, onSelectDate, selectedTime, onSelectTime }: ChooseTimeStepProps) => {
  const timeSlotsRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (selectedDate) {
      timeSlotsRef.current?.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
    }
  }, [selectedDate])

  return (
    <div className='space-y-4'>
      <div className='relative mx-auto max-w-70'>
        <Calendar
          mode='single'
          selected={selectedDate}
          onSelect={onSelectDate}
          disabled={date => !isBookableDate(date)}
          modifiers={{ available: date => isBookableDate(date) }}
          components={{ DayButton: AvailabilityDayButton }}
          showOutsideDays={false}
          buttonVariant='outline'
          className='bg-card w-full p-0 [--cell-size:--spacing(10)]'
          classNames={{
            months: 'w-full [&>*:first-child]:max-w-70 [&>*:first-child]:mx-auto [&>*:first-child]:pb-4',
            month: 'w-full [&>*:last-child]:mx-auto',
            day: '*:hover:bg-orange-600/10 *:rounded-full *:data-[selected-single=true]:bg-orange-600 dark:*:data-[selected-single=true]:hover:bg-orange-600 *:data-[selected-single=true]:text-white *:font-medium',
            weekdays: 'mt-2 flex',
            today: 'bg-transparent'
          }}
        />
      </div>

      {selectedDate && (
        <div ref={timeSlotsRef} className='space-y-4'>
          <div className='space-y-2'>
            <p className='text-muted-foreground text-xs font-medium tracking-wide uppercase'>Morning</p>
            <div className='grid grid-cols-3 gap-2'>
              {MORNING_SLOTS.map(time => (
                <Button
                  key={time}
                  variant='outline'
                  className={cn(
                    'hover:bg-background rounded-full',
                    selectedTime === time && 'bg-orange-600 text-white hover:bg-orange-600 hover:text-white'
                  )}
                  onClick={() => onSelectTime(time)}
                >
                  {time}
                </Button>
              ))}
            </div>
          </div>

          <div className='space-y-2'>
            <p className='text-muted-foreground text-xs font-medium tracking-wide uppercase'>Afternoon & Evening</p>
            <div className='grid grid-cols-3 gap-2 lg:grid-cols-4'>
              {AFTERNOON_SLOTS.map(time => (
                <Button
                  key={time}
                  variant='outline'
                  className={cn(
                    'hover:bg-background rounded-full',
                    selectedTime === time && 'bg-orange-600 text-white hover:bg-orange-600 hover:text-white'
                  )}
                  onClick={() => onSelectTime(time)}
                >
                  {time}
                </Button>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default ChooseTimeStep
