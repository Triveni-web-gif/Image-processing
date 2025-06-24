# 🖼️🔢 Verilog Image Multiplier

This project is a **hardware-based image processing system** designed in **Verilog HDL** to perform **pixel-by-pixel image multiplication**. It simulates how two images are combined at the pixel level, which is a core technique in tasks like image masking, blending, and enhancement.

Perfect for those learning digital design, Verilog, or building real-time image processing pipelines for FPGAs and ASICs.

---

## 💡 Features

- 🎛️ **Modular Verilog design** for scalability and reuse
- 🖥️ **Reads & writes image data** via memory modules
- ✖️ **Pixel-by-pixel multiplication** logic
- 🔍 **Simulated testbench** to verify operations
- 📄 **Parameter configuration** for image dimensions and bit width
- 🧪 Suitable for **FPGA implementation** and academic projects

---

## 🗂️ Project Structure

| File Name         | Description                                        |
|-------------------|----------------------------------------------------|
| `image_read.v`    | Reads pixel values from input image memory         |
| `image_write.v`   | Stores output image after processing               |
| `mul.v`           | Contains the core multiplication logic             |
| `parameter.v`     | Defines parameters like image width and depth      |
| `tb_simulation.v` | Testbench to simulate and verify the full pipeline |

---

## 🔧 How to Simulate

### 🧪 Using Icarus Verilog:

```bash
iverilog -o sim tb_simulation.v image_read.v image_write.v mul.v parameter.v
vvp sim
