import jax
import jax.numpy as jnp

print("jax:", jax.__version__)
print("backend:", jax.default_backend())
print("devices:", jax.devices())

x = jnp.ones((1024, 1024), dtype=jnp.float32)
y = (x @ x).block_until_ready()
print("mean:", float(jnp.mean(y)))
