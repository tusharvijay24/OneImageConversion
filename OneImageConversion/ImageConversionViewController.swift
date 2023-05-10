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
    @IBOutlet weak var convertButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Disable the convert button initially
        self.convertButton.isEnabled = false
        
        // Create and configure the activity indicator
        activityIndicator = UIActivityIndicatorView(style: .large)
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
                try self.convertAndSave(image: image, type: .PNG, to: pngURL)
                try self.convertAndSave(image: image, type: .JPEG, to: jpegURL)
                try self.convertAndSave(image: image, type: .TIFF, to: tiffURL)
                try self.convertAndSave(image: image, type: .GIF, to: gifURL)
                try self.convertToHEIFAndSave(image: image, to: heifURL)
                try self.convertToPDFAndSave(image: image, to: pdfURL)
                
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

extension ImageConversionViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        
        // Get the image from the info
        if let image = info[.originalImage] as? UIImage {
            // Display the image in the ImageView
            self.selectedImageView.image = image
            
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

extension ImageConversionViewController {
    
    private func convertAndSave(image: UIImage, type: SDImageFormat, to url: URL) throws {
        guard let data = image.sd_imageData(as: type) else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])
        }
        try data.write(to: url)
    }
    
    private func convertToHEIFAndSave(image: UIImage, to url: URL) throws {
        guard let ciImage = CIImage(image: image) else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to CIImage"])
        }
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let data = context.heifRepresentation(of: ciImage, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB(), options: [:]) else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to HEIF format"])
        }
        try data.write(to: url)
    }
    
    private func convertToPDFAndSave(image: UIImage, to url: URL) throws {
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: image.size))
        let data = pdfRenderer.pdfData { (context) in
            context.beginPage()
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        try data.write(to: url)
    }
}
