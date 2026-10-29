'use client'

// React Imports
import { useEffect, useMemo, useState } from 'react'

// Third-party Imports
import {
  addDays,
  eachDayOfInterval,
  endOfMonth,
  endOfWeek,
  format,
  isSameDay,
  isSameMonth,
  isToday,
  startOfMonth,
  startOfWeek
} from 'date-fns'

// Type Imports
import type { CalendarEvent } from '@/components/shadcn-studio/blocks/event-calendar-01/event-calendar-01'

// Component Imports
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { CalendarCell } from '@/components/shadcn-studio/blocks/event-calendar-01/content/calendar-cell'
import { EventItem } from '@/components/shadcn-studio/blocks/event-calendar-01/content/event-item'

// Hook Imports
import { useEventVisibility } from '@/hooks/use-event-visibility'

// Util Imports
import {
  DefaultStartHour,
  EventGap,
  EventHeight,
  getAllEventsForDay,
  getEventsForDay,
  getSpanningEventsForDay,
  sortEvents
} from '@/components/shadcn-studio/blocks/event-calendar-01/event-calendar-01'

interface MonthViewProps {
  currentDate: Date
  events: CalendarEvent[]
  onEventSelect: (event: CalendarEvent) => void
  onEventCreate: (startTime: Date) => void
}

export function MonthView({ currentDate, events, onEventSelect, onEventCreate }: MonthViewProps) {
  const weeks = useMemo(() => {
    const monthStart = startOfMonth(currentDate)
    const monthEnd = endOfMonth(monthStart)
    const calendarStart = startOfWeek(monthStart, { weekStartsOn: 0 })
    const calendarEnd = endOfWeek(monthEnd, { weekStartsOn: 0 })

    const days = eachDayOfInterval({ start: calendarStart, end: calendarEnd })
    const result: Date[][] = []
    let week: Date[] = []

    for (let i = 0; i < days.length; i++) {
      week.push(days[i])

      if (week.length === 7 || i === days.length - 1) {
        result.push(week)
        week = []
      }
    }

    return result
  }, [currentDate])

  const weekdays = useMemo(
    () => Array.from({ length: 7 }).map((_, i) => format(addDays(startOfWeek(new Date()), i), 'EEE')),
    []
  )

  const handleEventClick = (event: CalendarEvent, e: React.MouseEvent) => {
    e.stopPropagation()
    onEventSelect(event)
  }

  const [openPopoverDay, setOpenPopoverDay] = useState<string | null>(null)

  const handleCellClick = (day: Date, event: React.MouseEvent<HTMLDivElement>) => {
    const target = event.target as HTMLElement

    if (target.closest('[data-calendar-event]') || target.closest('[data-slot^="popover-"]')) return

    const startTime = new Date(day)

    startTime.setHours(DefaultStartHour, 0, 0)
    onEventCreate(startTime)
  }

  const [isMounted, setIsMounted] = useState(false)

  const { contentRef, getVisibleEventCount } = useEventVisibility({
    eventHeight: EventHeight,
    eventGap: EventGap
  })

  useEffect(() => {
    setIsMounted(true)
  }, [])

  return (
    <div data-slot='month-view' className='contents'>
      <div className='border-border/70 grid grid-cols-7 border-b'>
        {weekdays.map(day => (
          <div key={day} className='text-muted-foreground/70 py-2 text-center text-sm'>
            {day}
          </div>
        ))}
      </div>
      <div className='grid flex-1 auto-rows-fr'>
        {weeks.map((week, weekIndex) => (
          <div key={`week-${weekIndex}`} className='grid grid-cols-7 [&:last-child>*]:border-b-0'>
            {week.map((day, dayIndex) => {
              const dayEvents = getEventsForDay(events, day)
              const spanningEvents = getSpanningEventsForDay(events, day)
              const isCurrentMonth = isSameMonth(day, currentDate)
              const allDayEvents = [...spanningEvents, ...dayEvents]
              const allEvents = getAllEventsForDay(events, day)

              const isReferenceCell = weekIndex === 0 && dayIndex === 0

              const visibleCount = isMounted ? getVisibleEventCount(allDayEvents.length) : undefined
              const hasMore = visibleCount !== undefined && allDayEvents.length > visibleCount
              const remainingCount = hasMore ? allDayEvents.length - visibleCount : 0

              return (
                <div
                  key={day.toString()}
                  className='group border-border/70 data-outside-cell:bg-muted/25 data-outside-cell:text-muted-foreground/70 border-r border-b last:border-r-0'
                  data-today={isToday(day) || undefined}
                  data-outside-cell={!isCurrentMonth || undefined}
                >
                  <CalendarCell className='overflow-visible' onClick={event => handleCellClick(day, event)}>
                    <div className='group-data-today:bg-primary group-data-today:text-primary-foreground mt-1 inline-flex size-6 items-center justify-center rounded-full text-sm'>
                      {format(day, 'd')}
                    </div>
                    <div
                      ref={isReferenceCell ? contentRef : null}
                      className='min-h-[calc((var(--event-height)+var(--event-gap))*2)] overflow-visible sm:min-h-[calc((var(--event-height)+var(--event-gap))*3)] lg:min-h-[calc((var(--event-height)+var(--event-gap))*4)]'
                    >
                      {sortEvents(allDayEvents).map((event, index) => {
                        const isFirstDay = isSameDay(day, event.start)
                        const isLastDay = isSameDay(day, event.end)
                        const spansRight = !isLastDay && dayIndex < 6
                        const spansLeft = !isFirstDay && dayIndex > 0
                        const isHidden = isMounted && !!visibleCount && index >= visibleCount

                        if (!visibleCount) return null

                        return (
                          <div
                            key={isFirstDay ? event.id : `spanning-${event.id}-${day.toISOString().slice(0, 10)}`}
                            className='w-full aria-hidden:hidden'
                            aria-hidden={isHidden ? 'true' : undefined}
                          >
                            <EventItem
                              event={event}
                              view='month'
                              onClick={e => handleEventClick(event, e)}
                              isFirstDay={isFirstDay}
                              isLastDay={isLastDay}
                              spansLeft={spansLeft}
                              spansRight={spansRight}
                            />
                          </div>
                        )
                      })}

                      {hasMore && (
                        <Popover
                          open={openPopoverDay === format(day, 'yyyy-MM-dd')}
                          onOpenChange={open => setOpenPopoverDay(open ? format(day, 'yyyy-MM-dd') : null)}
                        >
                          <PopoverTrigger
                            render={
                              <button
                                className='focus-visible:border-ring focus-visible:ring-ring/50 text-muted-foreground hover:text-foreground hover:bg-muted/50 mt-[var(--event-gap)] flex h-[var(--event-height)] w-full items-center overflow-hidden px-1 text-left text-[10px] backdrop-blur-md transition outline-none select-none focus-visible:ring-[3px] sm:px-2 sm:text-xs'
                                onClick={e => e.stopPropagation()}
                              />
                            }
                          >
                            <span>
                              + {remainingCount} <span className='max-sm:sr-only'>more</span>
                            </span>
                          </PopoverTrigger>
                          <PopoverContent
                            align='center'
                            className='max-w-52 p-3'
                            style={{ '--event-height': `${EventHeight}px` } as React.CSSProperties}
                          >
                            <div className='space-y-2'>
                              <div className='text-sm font-medium'>{format(day, 'EEE d')}</div>
                              <div className='space-y-1'>
                                {sortEvents(allEvents).map(event => (
                                  <EventItem
                                    key={event.id}
                                    onClick={e => handleEventClick(event, e)}
                                    event={event}
                                    view='month'
                                    isFirstDay={isSameDay(day, event.start)}
                                    isLastDay={isSameDay(day, event.end)}
                                  />
                                ))}
                              </div>
                            </div>
                          </PopoverContent>
                        </Popover>
                      )}
                    </div>
                  </CalendarCell>
                </div>
              )
            })}
          </div>
        ))}
      </div>
    </div>
  )
}
