# Create a function that takes a single integer parameter, n, and returns the first n elements of the Fibonacci sequence.

#     g(1) = [ 0 ]
#     g(2) = [ 0, 1 ]
#     g(3) = [ 0, 1, 1 ]
#     g(4) = [ 0, 1, 1, 2 ]
#     g(5) = [ 0, 1, 1, 2, 3 ]



def fib(n):

    
    if n == 0:
        return []
    if n == 1:
        return [0]
    array = [ 0, 1]
    for i in range(2,n):
        array.append(array[i-2]+array[i-1])
        
    return array

print(fib(10))


