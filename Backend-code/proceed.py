from transformers import T5ForConditionalGeneration, T5Tokenizer
import torch

class Summarizer:
    def __init__(self, model_name="t5-small", device=None):
        self.model_name = model_name
        self.device = device if device else ("cuda" if torch.cuda.is_available() else "cpu")
        self.model = T5ForConditionalGeneration.from_pretrained(self.model_name).to(self.device)
        self.tokenizer = T5Tokenizer.from_pretrained(self.model_name, legacy=False)  

    def summarize(self, text, max_length=150, min_length=40):
        try:
            input_text = "summarize: " + text
            input_ids = self.tokenizer.encode(input_text, return_tensors="pt", max_length=512, truncation=True).to(self.device)
            summary_ids = self.model.generate(
                input_ids,
                max_length=max_length,
                min_length=min_length,
                length_penalty=2.0,
                num_beams=4,
                early_stopping=True
            )
            summary = self.tokenizer.decode(summary_ids[0], skip_special_tokens=True)
            return summary

        except Exception as e:
            return f"An error occurred during summarization: {str(e)}"


