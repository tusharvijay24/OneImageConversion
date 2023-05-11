//
//  ViewController.swift
//  OneImageConversion
//
//  Created by Tushar on 10/05/23.
//

import UIKit
import ZIPFoundation
import ImageIO
import MobileCoreServices
import SDWebImage

class ImageConversionViewController: UIViewController {
    
    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    var activityIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var selectedImageView: UIImageView!
    @IBOutlet weak var widthHeightLabel: UILabel!
    @IBOutlet weak var convertButton: UIButton!
    @IBOutlet weak var pixelWidthTextField: UITextField!
    @IBOutlet weak var pixelHeightTextField: UITextField!
    @IBOutlet weak var compressionQualityTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Disable the convert button initially
        self.convertButton.isEnabled = false
        
        // Create and configure the activity indicator
        let extractedExpr = UIActivityIndicatorView(style: .large)
        activityIndicator = extractedExpr
        activityIndicator.color = .blue
        activityIndicator.center = view.center
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
    }
    
    @IBAction func selectImage(_ sender: Any) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        self.present(picker, animated: true, completion: nil)
    }
    
    @IBAction func convertButtonTapped(_ sender: UIButton) {
        guard let image = self.selectedImageView.image else { return }
        
        // Get the pixel width and height from the text fields
        let pixelWidth = Int(pixelWidthTextField.text ?? "")
        let pixelHeight = Int(pixelHeightTextField.text ?? "")
        
        // Get the compression quality from the text field
        let compressionQuality = Double(compressionQualityTextField.text ?? "")
        
        // Start the activity indicator
        activityIndicator.startAnimating()
        
        // Start the conversion and zipping process
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Create a separate directory for the images
            let imagesDirectory = self.documentsDirectory.appendingPathComponent("images")
            do {
                try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Could not create images directory: \(error)")
                return
            }
            
            // Convert the image to different formats and write to disk
            let pngURL = imagesDirectory.appendingPathComponent("image.png")
            let jpegURL = imagesDirectory.appendingPathComponent("image.jpeg")
            let tiffURL = imagesDirectory.appendingPathComponent("image.tiff")
            let gifURL = imagesDirectory.appendingPathComponent("image.gif")
            let heifURL = imagesDirectory.appendingPathComponent("image.heif")
            let pdfURL = imagesDirectory.appendingPathComponent("image.pdf")
            
            do {
                try self.convertAndSave(image: image, type: .PNG, to: pngURL, pixelWidth: pixelWidth, pixelHeight: pixelHeight, compressionQuality: compressionQuality)
                try self.convertAndSave(image: image, type: .JPEG, to: jpegURL, pixelWidth: pixelWidth, pixelHeight: pixelHeight, compressionQuality: compressionQuality)
                try self.convertAndSave(image: image, type: .TIFF, to: tiffURL, pixelWidth: pixelWidth, pixelHeight: pixelHeight, compressionQuality: compressionQuality)
                try self.convertAndSave(image: image, type: .GIF, to: gifURL, pixelWidth: pixelWidth, pixelHeight: pixelHeight, compressionQuality: compressionQuality)
                try self.convertToHEIFAndSave(image: image, to: heifURL, pixelWidth: pixelWidth, pixelHeight: pixelHeight)
                try self.convertToPDFAndSave(image: image, to: pdfURL, pixelWidth: pixelWidth, pixelHeight: pixelHeight)
                
                // Zip the images
                let archiveURL = self.documentsDirectory.appendingPathComponent("archive.zip")
                if FileManager.default.fileExists(atPath: archiveURL.path) {
                    try FileManager.default.removeItem(at: archiveURL)
                }
                try FileManager.default.zipItem(at: imagesDirectory, to: archiveURL, shouldKeepParent: false)
                
                DispatchQueue.main.async {
                    
                    // Stop the activity indicator
                    self.activityIndicator.stopAnimating()
                    
                    // Share the zip file
                    let activityViewController = UIActivityViewController(activityItems: [archiveURL], applicationActivities: nil)
                    self.present(activityViewController, animated: true, completion: nil)
                    
                }
            } catch {
                DispatchQueue.main.async {
                    
                    // Stop the activity indicator
                    self.activityIndicator.stopAnimating()
                    
                    // Show an alert with the error
                    let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
}

// MARK: Image Picker Delegate

extension ImageConversionViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        
        if let image = info[.originalImage] as? UIImage {
                // Display the image in the ImageView
                self.selectedImageView.image = image

                // Update the width and height labels
                self.widthHeightLabel.text = "Width: \(Int(image.size.width))  Height: \(Int(image.size.height))"
               

                // Enable the convert button
                self.convertButton.isEnabled = true
            }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
        let alert = UIAlertController(title: "Image selection cancelled", message: "Please select an image to proceed", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}

// MARK: Conversion Methods

extension ImageConversionViewController {
    
    private func convertAndSave(image: UIImage, type: SDImageFormat, to url: URL, pixelWidth: Int?, pixelHeight: Int?, compressionQuality: Double?) throws {
        let resizedImage: UIImage? = {
            if let width = pixelWidth, let height = pixelHeight {
                let newSize = CGSize(width: width, height: height)
                return image.sd_resizedImage(with: newSize, scaleMode: .aspectFit)
            } else {
                return image
            }
        }()
        
        let compression = compressionQuality ?? 1.0
        guard let data = resizedImage?.sd_imageData(as: type, compressionQuality: compression) else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])
        }
        try data.write(to: url)
    }
    
    private func convertToHEIFAndSave(image: UIImage, to url: URL, pixelWidth: Int?, pixelHeight: Int?) throws {
        let resizedImage: UIImage? = {
            if let width = pixelWidth, let height = pixelHeight {
                let newSize = CGSize(width: width, height: height)
                return image.sd_resizedImage(with: newSize, scaleMode: .aspectFit)
            } else {
                return image
            }
        }()
        
        guard let ciImage = CIImage(image: resizedImage!) else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to CIImage"])
        }
        
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let data = context.heifRepresentation(of: ciImage, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB(), options: [:]) else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to HEIF format"])
        }
        try data.write(to: url)
    }
    
    private func convertToPDFAndSave(image: UIImage, to url: URL, pixelWidth: Int?, pixelHeight: Int?) throws {
        let resizedImage: UIImage? = {
            if let width = pixelWidth, let height = pixelHeight {
                let newSize = CGSize(width: width, height: height)
                return image.sd_resizedImage(with: newSize, scaleMode: .aspectFit)
            } else {
                return image
            }
        }()
        
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: resizedImage!.size))
        let data = pdfRenderer.pdfData { (context) in
            context.beginPage()
            resizedImage!.draw(in: CGRect(origin: .zero, size: resizedImage!.size))
        }
        try data.write(to: url)
    }
}


