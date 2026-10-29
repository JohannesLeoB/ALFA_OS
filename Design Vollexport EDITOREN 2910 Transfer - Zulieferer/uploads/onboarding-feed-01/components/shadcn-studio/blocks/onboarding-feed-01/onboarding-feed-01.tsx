'use client'

import { useState } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from '@/components/ui/accordion'
import { Button } from '@/components/ui/button'
import { LogInIcon, ImportIcon, PlusIcon, CircleCheckIcon, CircleDashedIcon } from 'lucide-react'

const items = [
  {
    title: 'Sign up and create an account',
    content: `To get started, log in with your organization account from your company.`,
    icon: (
      <LogInIcon />
    ),
    label: 'Sign up'
  },
  {
    title: 'Import your data',
    content: 'Connect your database to the new workspace by using one of 20+ database connectors.',
    icon: (
      <ImportIcon />
    ),
    label: 'Import'
  },
  {
    title: 'Create your first report',
    content: 'Use our drag-and-drop report builder to create your first report and share it with your team.',
    icon: (
      <PlusIcon />
    ),
    label: 'Create'
  }
]

function OnboardingFeed() {
  const [active, setActive] = useState<string[]>(['item-1'])
  const [completed, setCompleted] = useState<Set<number>>(new Set())

  const handleOpenChange = (val: string[]) => {
    setActive(val)
  }

  const handleComplete = (index: number) => {
    setCompleted(prev => {
      const next = new Set(prev)

      next.add(index)

      return next
    })

    const nextIndex = index + 1

    if (nextIndex < items.length) {
      setActive([`item-${nextIndex + 1}`])
    } else {
      setActive([])
    }
  }

  return (
    <Card className='w-full max-w-lg'>
      <CardHeader>
        <CardTitle className='leading-none font-semibold'>Hello, John !</CardTitle>
        <CardDescription>Let&apos;s set up your first data workspace</CardDescription>
      </CardHeader>
      <CardContent className='space-y-4 text-sm'>
        <Accordion
          className='w-full space-y-2 overflow-visible border-0 [&>*>[data-slot="accordion-content"]]:px-0'
          value={active}
          onValueChange={handleOpenChange}
        >
          {items.map((item, index) => {
            const isCompleted = completed.has(index)

            return (
              <AccordionItem key={index} value={`item-${index + 1}`} className='rounded-md border! bg-transparent'>
                <AccordionTrigger className='px-5'>
                  <span className='flex items-center gap-2'>
                    {isCompleted ? (
                      <CircleCheckIcon className='size-4 shrink-0' />
                    ) : (
                      <CircleDashedIcon className='size-4 shrink-0' />
                    )}
                    <span>{item.title}</span>
                  </span>
                </AccordionTrigger>
                <AccordionContent className='text-muted-foreground flex flex-col items-start gap-2 px-5'>
                  {item.content}
                  <Button
                    size='sm'
                    onClick={() => handleComplete(index)}
                    disabled={isCompleted || !(index === 0 || completed.has(index - 1))}
                    className='*:[svg]:size-4 *:[svg]:shrink-0'
                  >
                    {item.icon}
                    {item.label}
                  </Button>
                </AccordionContent>
              </AccordionItem>
            )
          })}
        </Accordion>
        <div className='flex justify-end gap-2'>
          <Button className='flex-1 max-sm:w-full' variant='outline'>
            Cancel
          </Button>
          <Button className='flex-1 max-sm:w-full' type='submit'>
            Continue
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}

export default OnboardingFeed
