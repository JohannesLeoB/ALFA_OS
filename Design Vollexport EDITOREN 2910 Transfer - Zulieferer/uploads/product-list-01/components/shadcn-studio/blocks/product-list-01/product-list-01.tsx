'use client'
import { useState } from 'react'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import { Separator } from '@/components/ui/separator'
import Heart from '@/assets/svg/heart'

import { cn } from '@/lib/utils'
import { ShoppingCartIcon } from 'lucide-react'

export type ProductItem = {
  image: string
  imgAlt: string
  name: string
  price: number
  salePrice?: number
  badges: string[]
}

type ProductProps = {
  products: ProductItem[]
}

const ProductList = ({ products }: ProductProps) => {
  const [liked, setLiked] = useState<Record<number, boolean>>({})

  return (
    <section className='bg-muted py-8 sm:py-16 lg:py-24'>
      <div className='mx-auto max-w-7xl space-y-12 px-4 sm:space-y-16 sm:px-6 lg:space-y-24 lg:px-8'>
        <div className='space-y-4'>
          <p className='text-sm font-medium'>Samsung watch</p>
          <h2 className='text-2xl font-semibold sm:text-3xl lg:text-4xl'>All New Collection</h2>
        </div>

        <div className='grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3'>
          {/* Product Cards */}
          {products.map((product, index) => (
            <Card key={index} className={cn('ring-0', product.salePrice && 'relative')}>
              {/* Sale Badge */}
              {product.salePrice && (
                <Badge className='bg-destructive/10 text-destructive focus-visible:ring-destructive/20 dark:focus-visible:ring-destructive/40 [a]:hover:bg-destructive/5 absolute top-6 left-6 h-6 rounded-md px-3 py-1 uppercase focus-visible:outline-none'>
                  Sale
                </Badge>
              )}

              <CardContent>
                {/* Product Image */}
                <a href='#'>
                  <img src={product.image} alt={product.imgAlt} className='mx-auto size-50' />
                </a>
              </CardContent>
              <CardContent className='flex flex-1 flex-col justify-between'>
                {/* Product Details */}
                <div className='space-y-4'>
                  <div className='flex flex-col gap-2 text-center'>
                    <a href='#'>
                      <h3 className='text-xl font-semibold'>{product.name}</h3>
                    </a>
                    <div className='flex items-center justify-center gap-2'>
                      {product.badges.map((badge, idx) => (
                        <Badge
                          key={idx}
                          className='rounded-sm bg-green-600/10 text-green-600 focus-visible:ring-green-600/20 focus-visible:outline-none dark:bg-green-400/10 dark:text-green-400 dark:focus-visible:ring-green-400/40'
                        >
                          {badge}
                        </Badge>
                      ))}
                    </div>
                  </div>

                  <Separator />

                  {/* Product Price */}
                  <div className='flex items-center justify-between'>
                    {!product.salePrice && <span className='text-2xl font-semibold'>${product.price.toFixed(2)}</span>}
                    {product.salePrice && (
                      <div className='flex items-center gap-2.5'>
                        <span className='text-2xl font-semibold'>${product.salePrice.toFixed(2)}</span>
                        <span className='text-muted-foreground text-base font-medium line-through'>
                          ${product.price.toFixed(2)}
                        </span>
                      </div>
                    )}

                    <div>
                      <Button
                        variant='ghost'
                        size='icon'
                        onClick={() =>
                          setLiked(prev => ({
                            ...prev,
                            [index]: !prev[index]
                          }))
                        }
                      >
                        <Heart
                          className={cn('size-4', {
                            'fill-destructive stroke-destructive': liked[index]
                          })}
                        />
                        <span className='sr-only'>Explore</span>
                      </Button>

                      <Button variant='ghost' className='size-9'>
                        <ShoppingCartIcon />
                      </Button>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </section>
  )
}

export default ProductList
