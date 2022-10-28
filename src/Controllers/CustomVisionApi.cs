using Microsoft.Azure.CognitiveServices.Vision.ComputerVision;
using Microsoft.Azure.CognitiveServices.Vision.ComputerVision.Models;
namespace drumbeat.Models;

public class CustomVisionApi
{
    public class AnalyzeImageSample
    {
        public static async Task<List<FaceResult>> RunAsync(string endpoint, string key, Stream imageStream, string imagePath)
        {
            ComputerVisionClient computerVision = new ComputerVisionClient(new ApiKeyServiceClientCredentials(key))
            {
                Endpoint = endpoint
            };

            List<VisualFeatureTypes?> features = new List<VisualFeatureTypes?>()
            {
                VisualFeatureTypes.Categories, VisualFeatureTypes.Description,
                VisualFeatureTypes.Faces, VisualFeatureTypes.ImageType,
                VisualFeatureTypes.Tags, VisualFeatureTypes.Adult,
                VisualFeatureTypes.Color, VisualFeatureTypes.Brands,
                VisualFeatureTypes.Objects
            };

            Console.WriteLine($"Image {imagePath} being analyzed...");
            var r = await AnalyzeLocalAsync(computerVision, imagePath, imageStream, features);
            return r;
        }

        // Analyze a local image
        private static async Task<List<FaceResult>> AnalyzeLocalAsync(ComputerVisionClient computerVision, string imagePath, Stream imageStream, List<VisualFeatureTypes?> features)
        {
            using (imageStream)
            {
                try
                {
                    imageStream.Position = 0;
                    ImageAnalysis analysis = await computerVision.AnalyzeImageInStreamAsync(imageStream, visualFeatures: features);
                    var result = FaceResults(analysis);
                    return result;
                }
                catch (Exception e)
                {
                    Console.WriteLine(e.InnerException);
                    Console.WriteLine(e.Message);
                }

                // if no results are found, return an empty, typed array
                return new List<FaceResult>();
            }
        }

        private static List<FaceResult> FaceResults(ImageAnalysis analysis)
        {
            List<FaceResult> faceResults = new List<FaceResult>();

            foreach (var face in analysis.Faces)
            {
                FaceResult f = new FaceResult();

                f.Gender = face.Gender.ToString();
                f.Age = face.Age;
                f.Coordinates = new int[] {
                    face.FaceRectangle.Left, face.FaceRectangle.Top,
                    face.FaceRectangle.Left + face.FaceRectangle.Width,
                    face.FaceRectangle.Top + face.FaceRectangle.Height
                    };

                faceResults.Add(f);
            }
            return faceResults;
        }

        private static void DisplayAdultResults(ImageAnalysis analysis)
        {
            //racy content
            Console.WriteLine("Adult:");
            Console.WriteLine("Is adult content: {0} with confidence {1}", analysis.Adult.IsAdultContent, analysis.Adult.AdultScore);
            Console.WriteLine("Has racy content: {0} with confidence {1} ", analysis.Adult.IsRacyContent, analysis.Adult.RacyScore);
            Console.WriteLine("\n");
        }

        private static void DisplayTagResults(ImageAnalysis analysis)
        {
            //image tags
            Console.WriteLine("Tags, Confidence:");
            foreach (var tag in analysis.Tags)
            {
                Console.WriteLine("{0} ({1})", tag.Name, tag.Confidence);
            }
            Console.WriteLine("\n");
        }

        private static void DisplayImageDescription(ImageAnalysis analysis)
        {
            //captioning
            Console.WriteLine("Captions:");
            foreach (var caption in analysis.Description.Captions)
            {
                Console.WriteLine("{0} with confidence {1}", caption.Text, caption.Confidence);
            }
            Console.WriteLine("\n");
        }

        private static void DisplayObjectDetectionResults(ImageAnalysis analysis)
        {
            //objects
            Console.WriteLine("Objects:");
            foreach (var obj in analysis.Objects)
            {
                Console.WriteLine("{0} with confidence {1} at location {2},{3},{4},{5}",
                    obj.ObjectProperty, obj.Confidence,
                    obj.Rectangle.X, obj.Rectangle.X + obj.Rectangle.W,
                    obj.Rectangle.Y, obj.Rectangle.Y + obj.Rectangle.H);
            }
            Console.WriteLine("\n");
        }

        private static void DisplayBrandDetectionResults(ImageAnalysis analysis)
        {
            //brands
            Console.WriteLine("Brands:");
            foreach (var brand in analysis.Brands)
            {
                Console.WriteLine("Logo of {0} with confidence {1} at location {2},{3},{4},{5}",
                    brand.Name, brand.Confidence,
                    brand.Rectangle.X, brand.Rectangle.X + brand.Rectangle.W,
                    brand.Rectangle.Y, brand.Rectangle.Y + brand.Rectangle.H);
            }
            Console.WriteLine("\n");
        }

        private static void DisplayDomainSpecificResults(ImageAnalysis analysis)
        {
            //celebrities
            Console.WriteLine("Celebrities:");
            foreach (var category in analysis.Categories)
            {
                if (category.Detail?.Celebrities != null)
                {
                    foreach (var celeb in category.Detail.Celebrities)
                    {
                        Console.WriteLine("{0} with confidence {1} at location {2},{3},{4},{5}",
                            celeb.Name, celeb.Confidence,
                            celeb.FaceRectangle.Left, celeb.FaceRectangle.Top,
                            celeb.FaceRectangle.Height, celeb.FaceRectangle.Width);
                    }
                }
            }

            //landmarks
            Console.WriteLine("Landmarks:");
            foreach (var category in analysis.Categories)
            {
                if (category.Detail?.Landmarks != null)
                {
                    foreach (var landmark in category.Detail.Landmarks)
                    {
                        Console.WriteLine("{0} with confidence {1}", landmark.Name, landmark.Confidence);
                    }
                }
            }
            Console.WriteLine("\n");
        }

        private static void DisplayColorSchemeResults(ImageAnalysis analysis)
        {
            //color scheme
            Console.WriteLine("Color Scheme:");
            Console.WriteLine("Is black and white?: " + analysis.Color.IsBWImg);
            Console.WriteLine("Accent color: " + analysis.Color.AccentColor);
            Console.WriteLine("Dominant background color: " + analysis.Color.DominantColorBackground);
            Console.WriteLine("Dominant foreground color: " + analysis.Color.DominantColorForeground);
            Console.WriteLine("Dominant colors: " + string.Join(",", analysis.Color.DominantColors));
        }

        private static void DisplayImageCategoryResults(ImageAnalysis analysis)
        {
            //categorize
            Console.WriteLine("Categories:\n");
            foreach (var category in analysis.Categories)
            {
                Console.WriteLine("{0} with confidence {1}", category.Name, category.Score);
            }
            Console.WriteLine("\n");
        }

        private static void DisplayImageTypeResults(ImageAnalysis analysis)
        {
            //image types
            Console.WriteLine("Image Type:"); //please look at the API documentation to know more about what the scores mean
            Console.WriteLine("Clip Art Type: " + analysis.ImageType.ClipArtType);
            Console.WriteLine("Line Drawing Type: " + analysis.ImageType.LineDrawingType);
            Console.WriteLine("\n");
        }
    }
}
