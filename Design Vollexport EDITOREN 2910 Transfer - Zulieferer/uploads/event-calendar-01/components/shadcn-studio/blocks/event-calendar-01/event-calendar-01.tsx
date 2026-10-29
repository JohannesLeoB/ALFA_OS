'use client'

// React Imports
import { useEffect, useMemo, useState } from 'react'

// Third-party Imports
import {
  addDays,
  addMonths,
  addWeeks,
  endOfWeek,
  format,
  isSameDay,
  isSameMonth,
  startOfWeek,
  subMonths,
  subWeeks
} from 'date-fns'

// Component Imports
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuShortcut,
  DropdownMenuTrigger
} from '@/components/ui/dropdown-menu'
import { DayView } from '@/components/shadcn-studio/blocks/event-calendar-01/content/day-view'
import { MonthView } from '@/components/shadcn-studio/blocks/event-calendar-01/content/month-view'
import { WeekView } from '@/components/shadcn-studio/blocks/event-calendar-01/content/week-view'

// Util Imports
import { cn } from '@/lib/utils'
import { PlusIcon, CalendarClockIcon, ChevronLeftIcon, ChevronRightIcon, ChevronDownIcon } from 'lucide-react'

export const EventHeight = 29
export const EventGap = 4
export const WeekCellsHeight = 72
export const StartHour = 0
export const EndHour = 24
export const DefaultStartHour = 9

export type EventColor = 'family' | 'business' | 'personal' | 'holiday' | 'etc'

export type CalendarEvent = {
  id: string
  title: string
  description?: string
  start: Date
  end: Date
  allDay?: boolean
  color?: EventColor
  location?: string
}

export type CalendarView = 'month' | 'week' | 'day'

export function getEventColorClasses(color: CalendarEvent['color']): string {
  switch (color) {
    case 'family':
      return 'bg-amber-200/50 text-amber-950/80 dark:bg-amber-400/25 dark:text-amber-200 shadow-amber-700/8'
    case 'business':
      return 'bg-violet-200/50 text-violet-950/80 dark:bg-violet-400/25 dark:text-violet-200 shadow-violet-700/8'
    case 'personal':
      return 'bg-rose-200/50 text-rose-950/80 dark:bg-rose-400/25 dark:text-rose-200 shadow-rose-700/8'
    case 'holiday':
      return 'bg-emerald-200/50 text-emerald-950/80 dark:bg-emerald-400/25 dark:text-emerald-200 shadow-emerald-700/8'
    case 'etc':
    default:
      return 'bg-sky-200/50 text-sky-950/80 dark:bg-sky-400/25 dark:text-sky-200 shadow-sky-700/8'
  }
}

export function getBorderRadiusClasses(isFirstDay: boolean, isLastDay: boolean): string {
  if (isFirstDay && isLastDay) return 'rounded-sm'
  if (isFirstDay) return 'rounded-l-sm rounded-tr-none rounded-br-none'
  if (isLastDay) return 'rounded-r-sm rounded-tl-none rounded-bl-none'

  return 'rounded-none'
}

/**
 * Extend the bar into the next day cell (right only) so multi-day events read as one
 * continuous strip across the month grid instead of visibly breaking at each cell border.
 */
export function getMonthViewBleedClasses(spansRight: boolean): string {
  if (!spansRight) return ''

  return cn(
    'overflow-visible',
    'after:absolute after:top-0 after:bottom-0 after:left-full after:z-0 after:w-[calc(0.125rem+1px+0.125rem)] after:rounded-none after:bg-inherit after:content-[""] sm:after:w-[calc(0.25rem+1px+0.25rem)]'
  )
}

export function getMonthViewEventPaddingClasses(spansLeft: boolean, spansRight: boolean): string {
  if (!spansLeft && !spansRight) return 'px-1 sm:px-2'

  return cn(!spansLeft && 'pl-1 sm:pl-2', !spansRight && 'pr-1 sm:pr-2', spansLeft && 'pl-0', spansRight && 'pr-0')
}

export function isMultiDayEvent(event: CalendarEvent): boolean {
  return event.allDay || event.start.getDate() !== event.end.getDate()
}

export function getEventsForDay(events: CalendarEvent[], day: Date): CalendarEvent[] {
  return events.filter(event => isSameDay(day, event.start)).sort((a, b) => a.start.getTime() - b.start.getTime())
}

export function sortEvents(events: CalendarEvent[]): CalendarEvent[] {
  return [...events].sort((a, b) => {
    const aIsMultiDay = isMultiDayEvent(a)
    const bIsMultiDay = isMultiDayEvent(b)

    if (aIsMultiDay && !bIsMultiDay) return -1
    if (!aIsMultiDay && bIsMultiDay) return 1

    return a.start.getTime() - b.start.getTime()
  })
}

export function getSpanningEventsForDay(events: CalendarEvent[], day: Date): CalendarEvent[] {
  return events.filter(event => {
    if (!isMultiDayEvent(event)) return false

    return !isSameDay(day, event.start) && (isSameDay(day, event.end) || (day > event.start && day < event.end))
  })
}

export function getAllEventsForDay(events: CalendarEvent[], day: Date): CalendarEvent[] {
  return events.filter(
    event => isSameDay(day, event.start) || isSameDay(day, event.end) || (day > event.start && day < event.end)
  )
}

export interface EventCalendar01Props {
  events: CalendarEvent[]
  initialView?: CalendarView
  className?: string
  onEventSelect?: (event: CalendarEvent) => void
  onEventCreate?: (startTime: Date) => void
}

const EventCalendar01 = ({
  events,
  initialView = 'month',
  className,
  onEventSelect = () => {},
  onEventCreate = () => {}
}: EventCalendar01Props) => {
  const [currentDate, setCurrentDate] = useState(() => new Date())
  const [view, setView] = useState<CalendarView>(initialView)

  const goToToday = () => setCurrentDate(new Date())

  const goToPrevious = () => {
    setCurrentDate(current => {
      if (view === 'month') return subMonths(current, 1)
      if (view === 'week') return subWeeks(current, 1)

      return addDays(current, -1)
    })
  }

  const goToNext = () => {
    setCurrentDate(current => {
      if (view === 'month') return addMonths(current, 1)
      if (view === 'week') return addWeeks(current, 1)

      return addDays(current, 1)
    })
  }

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (
        e.target instanceof HTMLInputElement ||
        e.target instanceof HTMLTextAreaElement ||
        (e.target instanceof HTMLElement && e.target.isContentEditable)
      ) {
        return
      }

      switch (e.key.toLowerCase()) {
        case 'm':
          setView('month')
          break
        case 'w':
          setView('week')
          break
        case 'd':
          setView('day')
          break
      }
    }

    window.addEventListener('keydown', handleKeyDown)

    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [])

  const viewTitle = useMemo(() => {
    if (view === 'month') return format(currentDate, 'MMMM yyyy')

    if (view === 'week') {
      const start = startOfWeek(currentDate, { weekStartsOn: 0 })
      const end = endOfWeek(currentDate, { weekStartsOn: 0 })

      return isSameMonth(start, end)
        ? format(start, 'MMMM yyyy')
        : `${format(start, 'MMM')} - ${format(end, 'MMM yyyy')}`
    }

    return format(currentDate, 'EEE MMMM d, yyyy')
  }, [currentDate, view])

  return (
    <section className='p-3'>
      <div className='h-[calc(100dvh-2rem)]'>
        <div className={cn('bg-card flex flex-col rounded-lg border', className)}>
          <div
            className='flex flex-col has-data-[slot=month-view]:flex-1'
            style={
              {
                '--event-height': `${EventHeight}px`,
                '--event-gap': `${EventGap}px`,
                '--week-cells-height': `${WeekCellsHeight}px`
              } as React.CSSProperties
            }
          >
            <div className='flex items-center justify-between gap-1 p-2 sm:p-4'>
              <div className='flex items-center gap-1 max-sm:justify-between sm:gap-4'>
                <div className='flex items-center gap-1'>
                  <Button className='max-sm:hidden md:max-lg:h-8'>
                    <PlusIcon />
                    <span>New event</span>
                  </Button>
                  <Button size='icon-sm' className='sm:hidden'>
                    <PlusIcon />
                  </Button>
                  <Button variant='outline' className='max-sm:hidden md:max-lg:h-8' onClick={goToToday}>
                    <CalendarClockIcon />
                    <span>Today</span>
                  </Button>
                  <Button variant='outline' size='icon-sm' className='sm:hidden' onClick={goToToday}>
                    <CalendarClockIcon />
                  </Button>
                </div>
              </div>
              <div className='flex items-center gap-1'>
                <Button variant='ghost' size='icon-sm' onClick={goToPrevious} aria-label='Previous'>
                  <ChevronLeftIcon />
                </Button>
                <h2 className='text-sm font-semibold sm:text-lg md:text-xl'>{viewTitle}</h2>
                <Button variant='ghost' size='icon-sm' onClick={goToNext} aria-label='Next'>
                  <ChevronRightIcon />
                </Button>
              </div>
              <div className='flex items-center gap-2'>
                <DropdownMenu>
                  <DropdownMenuTrigger
                    render={
                      <Button variant='outline' className='max-sm:h-8!'>
                        <span>
                          <span className='sm:hidden' aria-hidden='true'>
                            {view.charAt(0).toUpperCase()}
                          </span>
                          <span className='max-sm:sr-only'>{view.charAt(0).toUpperCase() + view.slice(1)}</span>
                        </span>
                        <ChevronDownIcon className='-me-1 opacity-60' />
                      </Button>
                    }
                  />
                  <DropdownMenuContent align='end' className='min-w-32'>
                    <DropdownMenuItem onClick={() => setView('month')}>
                      Month <DropdownMenuShortcut>M</DropdownMenuShortcut>
                    </DropdownMenuItem>
                    <DropdownMenuItem onClick={() => setView('week')}>
                      Week <DropdownMenuShortcut>W</DropdownMenuShortcut>
                    </DropdownMenuItem>
                    <DropdownMenuItem onClick={() => setView('day')}>
                      Day <DropdownMenuShortcut>D</DropdownMenuShortcut>
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              </div>
            </div>
            <div className='flex flex-1 flex-col'>
              {view === 'month' && (
                <MonthView
                  currentDate={currentDate}
                  events={events}
                  onEventSelect={onEventSelect}
                  onEventCreate={onEventCreate}
                />
              )}
              {view === 'week' && (
                <WeekView
                  currentDate={currentDate}
                  events={events}
                  onEventSelect={onEventSelect}
                  onEventCreate={onEventCreate}
                />
              )}
              {view === 'day' && (
                <DayView
                  currentDate={currentDate}
                  events={events}
                  onEventSelect={onEventSelect}
                  onEventCreate={onEventCreate}
                />
              )}
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

export default EventCalendar01
