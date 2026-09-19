import numpy as np

np.random.seed(42)

for i in range(100):

    window = np.random.randint(0, 256, size=9)
    weights = np.random.randint(-128, 128, size=9)

    expected = np.sum(window * weights)

    print(f"Test {i}:")
    print("window  =", window.tolist())
    print("weights =", weights.tolist())
    print("expected =", expected)